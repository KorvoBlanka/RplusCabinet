package RplusCabinet::Controller::API::Account;

use Mojo::Base 'Mojolicious::Controller';

use Rplus::DB;

use Rplus::Model::Account::Manager;
use Rplus::Model::Event::Manager;
use Rplus::Model::Location::Manager;
use Rplus::Model::Partner::Manager;

use JSON;
use MIME::Lite;
use Net::SMTP::SSL;
use DateTime;
use DateTime::Format::Strptime;


my $parser = DateTime::Format::Strptime->new(pattern => '%Y-%m-%d %H:%M:%S');
my $ua = Mojo::UserAgent->new;

sub _trim {
    my $s = shift; $s =~ s/^\s+|\s+$//g; return $s
}

sub _log_event {
    my $text = shift;
    my $account = shift;
    my $event = Rplus::Model::Event->new;
    $event->text($text);
    $event->account($account);
    $event->save(insert => 1);
}

sub _send_email {
    my $to = shift;
    my $subject = shift;
    my $message = shift;
    my $config = shift;

    my $from = $config->{'user'};

    my $msg = MIME::Lite->new(
                   From     => $from,
                   To       => $to,
                   Subject  => $subject,
                   Data     => $message
                   );
    $msg->attr("content-type" => "text/html; charset=UTF-8");
    #$msg->send('smtp', 'smtp.yandex.ru', AuthUser=>'info@rplusmgmt.com', AuthPass=>'ckj;ysqgfhjkm', Port => 587);

    my $smtp = Net::SMTP::SSL->new($config->{'host'}, Port => $config->{'port'});
    if ($smtp) {
      $smtp->auth($config->{'user'}, $config->{'pass'});
      $smtp->mail($config->{'user'});
      $smtp->to($to);
      $smtp->data();
      $smtp->datasend($msg->as_string) or say "Error:".$smtp->message();
      $smtp->dataend();
      $smtp->quit();
    }
}

sub _generate_code {
    my @chars = ("A".."Z", "a".."z", "0".."9");
    my $reg_code;
    $reg_code .= $chars[rand @chars] for 1..20;

    return $reg_code;
}

sub get_by_name {
    my $self = shift;
    my $name = $self->param('name');

    my $account = Rplus::Model::Account::Manager->get_objects(query => [name => $name, del_date => undef])->[0];

    return $self->render(json => {status => 'fail'}) unless $account;

    my $res = {
        name => $account->name,
        balance => $account->balance,
        user_count => $account->user_count,
        mode => $account->mode,
        location_id => $account->location_id,
    };

    return $self->render(json => {status => 'ok', data => $res});
}

sub update {
  my $self = shift;
  my $id = $self->param('id');
  my $mode = $self->param('mode');
  my $user_count = $self->param('user_count');

  my $account = Rplus::Model::Account::Manager->get_objects(query => [id => $id, del_date => undef])->[0];

  my $lc = $account->last_changes;
  if ($lc) {
    my $now = DateTime->now( time_zone => 'local' )->set_time_zone('floating');;

    my $delta = $now->subtract_datetime($lc);
    return $self->render(json => {status => 'fail'}) if $delta->days < 1;
  }

  $account->mode($mode);
  $account->user_count($user_count);
  $account->last_changes('now()');
  $account->save(changes_only => 1);

  return $self->render(json => {status => 'ok'});

}


sub begin_restore {
    my $self = shift;
    my $email = $self->param('email');

    my $account = Rplus::Model::Account::Manager->get_objects(query => [email => $email, del_date => undef])->[0];

    $account->reg_code(_generate_code());
    $account->save(changes_only => 1);

    my $subject = 'Восстановление доступа к кабинету RplusMgmt';
    my $message = 'Для восстановления доступа к личному кабинету перейдите по ссылке http://' . $self->config->{site_name} . '/api/account/confirm_restore?reg_code=' . $account->reg_code;
    _send_email($email, $subject, $message, $self->config->{email});

    _log_event('password restoration asked', $account->id);

    return $self->render(json => {status => 'ok'});
}

sub confirm_restore {
    my $self = shift;
    my $reg_code = $self->param('reg_code');

    my $account = Rplus::Model::Account::Manager->get_objects(query => [reg_code => $reg_code, del_date => undef])->[0];

    $self->flash(reg_code => $reg_code);

    _log_event('password restoration confirmed', $account->id);

    return $self->redirect_to('/passwdrestore');
}

sub restore {
    my $self = shift;
    my $reg_code = $self->param('reg_code');
    my $new_password = $self->param('new_password');

    my $account = Rplus::Model::Account::Manager->get_objects(query => [reg_code => $reg_code, del_date => undef])->[0];

    $account->password($new_password);
    $account->reg_code(_generate_code());
    $account->save(changes_only => 1);

    $self->session->{'user'} = {
        id => $account->id,
        login => $account->email,
    };

    $self->flash(show_message => 1, title => 'RplusMgmt', message => '<p>Доступ к кабинету восстановлен</p>');

    _log_event('password restored', $account->id);

    return $self->redirect_to('/main');
}

sub passwdchange {
    my $self = shift;
    my $email = $self->param('email');
    my $old_password = $self->param('old_password');
    my $new_password = $self->param('new_password');

    my $account = Rplus::Model::Account::Manager->get_objects(query => [email => $email, del_date => undef])->[0];
    unless ($account->password eq $old_password) {
        return $self->render(json => {status => 'failed'});
    } else {
        $account->password($new_password);
        $account->save(changes_only => 1);

        _log_event('password changed', $account->id);

        return $self->render(json => {status => 'ok'});
    }
}

sub create {
    my $self = shift;

    # Create account
    my $account = Rplus::Model::Account->new;

    # Input params
    my $account_name = $self->param('account_name');
    my $email = $self->param('email');
    my $password = $self->param('password');
    my $offer_type = $self->param('offer_type');
    my $location_id = $self->param('location_id');

    my $partner_code = $self->param('partner_code');

    # Save
    $account->balance(0);
    $account->user_count(1);

    if ($account_name) {
        $account->name(_trim($account_name));
    }
    $account->email(_trim($email));
    $account->password($password);
    $account->reg_code(_generate_code());
    $account->mode($offer_type);
    $account->location_id($location_id);

    my $partner = Rplus::Model::Partner::Manager->get_objects(query => [code => $partner_code])->[0];
    if ($partner) {
        $account->partner_id($partner->id);
        $account->balance($partner->balance_bonus);
    }

    eval {
        $account->save(insert => 1);
        1;
    } or do {
        return $self->render(json => {error => $@}, status => 500);
    };

    unless ($account_name) {
        $account->name('account' . $account->id);
        $account->save(changes_only => 1);
    }

    my $subject = 'Подтверждение регистрации RplusMgmt';
    my $message = 'Для подтверждения регистрации перейдите по ссылке http://' . $self->config->{site_name} . '/api/account/confirm?reg_code=' . $account->reg_code;
    _send_email($email, $subject, $message, $self->config->{email});

    _log_event('account created', $account->id);

    return $self->render(json => {status => 'success', });
}

sub confirm {
    my $self = shift;

    my $reg_code = $self->param('reg_code');
    my $account = Rplus::Model::Account::Manager->get_objects(query => [reg_code => $reg_code, del_date => undef])->[0];

    if (!$account) {
        $self->flash(
            show_message => 1,
            title => 'Аккаунт не найден',
            message => '<p>Вероятно, регистрация уже подтверждена</p><p>Перейти в личный <a href="/cabinet">кабинет</a></p>',
        );
        return $self->redirect_to('/main');
    }

    eval {
        $account->reg_code(_generate_code());
        $account->save(changes_only => 1);
        1;
    } or do {
        return $self->render(json => {error => $@}, status => 500);
    };

    _log_event('registration confirmed', $account->id);

    $self->session->{'user'} = {
        id => $account->id,
        login => $account->email,
    };

    my $location = Rplus::Model::Location::Manager->get_objects(query => [id => $account->location_id])->[0];
    my $server_name = $location->server_name;
    my $service_url = "http://$server_name/service/create_account";

    my $tx = $ua->get($service_url, form => {
        email => $account->email,
        name =>  $account->name,
        location_id => $account->location_id,
    });


    my $res;
    if (($res = $tx->success) && ($res->json->{'status'} eq 'success')) {
        _log_event('instance created', $account->id);
        $self->flash(
            show_message => 1,
            title => 'Регистрация ' . $account->email . ' подтверждена',
            message => 'Аккаунт активирован, добро пожаловать!',
        );
    } else {
        _log_event('failed to create instance', $account->id);
        $self->flash(
            show_message => 1,
            title => 'Регистрация ' . $account->email . ' подтверждена',
            message => 'При активации аккаунта произошла непредвиденная ошибка, обратитесь в службу поддержки',
        );
    }

    return $self->redirect_to('/cabinet');
}

1;
