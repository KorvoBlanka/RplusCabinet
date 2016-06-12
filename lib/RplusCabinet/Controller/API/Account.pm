package RplusCabinet::Controller::API::Account;

use Mojo::Base 'Mojolicious::Controller';

use Rplus::DB;
use Template;

use Rplus::Model::Account;
use Rplus::Model::Account::Manager;
use Rplus::Model::Event;
use Rplus::Model::Event::Manager;

use JSON;
use IPC::Open2;
use MIME::Lite;
#use MIME::Lite::TT::HTML; 
use Net::SMTP::SSL;

use Mojo::IOLoop;

my $template = Template->new({
        ABSOLUTE => 1,
    });
my $dbh = Rplus::DB->new_or_cached->dbh;

my $host = 'smtp.yandex.ru';
my $mail = 'info@rplusmgmt.com';

my $user = 'info@rplusmgmt.com';
my $pass = 'DU21071969';
my $port = 465;

my $ua = Mojo::UserAgent->new;

sub log_event {
    my $text = shift;
    my $account = shift;
    my $event = Rplus::Model::Event->new;
    $event->text($text);
    $event->account($account);
    $event->save(insert => 1);
}

sub send_email {
    my $to = shift;
    my $subject = shift;
    my $message = shift;
    
    my $from = 'info@rplusmgmt.com';
  
    my $msg = MIME::Lite->new(
                   From     => $from,
                   To       => $to,
                   Subject  => $subject,
                   Data     => $message
                   );               
    $msg->attr("content-type" => "text/html; charset=UTF-8");     
    #$msg->send('smtp', 'smtp.yandex.ru', AuthUser=>'info@rplusmgmt.com', AuthPass=>'ckj;ysqgfhjkm', Port => 587);

    my $smtp = Net::SMTP::SSL->new($host, Port => $port); # or die "Can't connect";
    $smtp->auth($user, $pass); # or die "Can't authenticate:".$smtp->message();
    $smtp->mail($mail); # or die "Error:".$smtp->message();
    $smtp->to($to); # or die "Error:".$smtp->message();
    $smtp->data(); # or die "Error:".$smtp->message();
    $smtp->datasend($msg->as_string); # or die "Error:".$smtp->message();
    $smtp->dataend(); # or die "Error:".$smtp->message();
    $smtp->quit(); # or die "Error:".$smtp->message();

}

sub generate_code {
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

sub set_user_count {
    my $self = shift;
    my $id = $self->param('id');
    my $user_count = $self->param('user_count');
    
    my $account = Rplus::Model::Account::Manager->get_objects(query => [id => $id, del_date => undef])->[0];
    $account->user_count($user_count);
    $account->save(changes_only => 1);
    
    return $self->render(json => {status => 'ok'});
}

sub set_mode {
    my $self = shift;
    my $id = $self->param('id');
    my $mode = $self->param('mode');
    
    if($mode ne 'all' && $mode ne 'sale' && $mode ne 'rent') {
        return $self->render(json => {status => 'unknown mode'});
    }

    my $account = Rplus::Model::Account::Manager->get_objects(query => [id => $id, del_date => undef])->[0];
    $account->mode($mode);
    $account->save(changes_only => 1);
    
    return $self->render(json => {status => 'ok'});
}

sub set_option {
    my $self = shift;
    
    return $self->render(json => {status => 'ok'});    
}

sub get_option {
    my $self = shift;

    return $self->render(json => {status => 'ok',});
}

sub begin_restore {
    my $self = shift;
    my $email = $self->param('email');
    
    my $account = Rplus::Model::Account::Manager->get_objects(query => [email => $email, del_date => undef])->[0];
    
    $account->reg_code(generate_code());
    $account->save(changes_only => 1);
    
    my $subject = 'Восстановление доступа к кабинету RplusMgmt';
    my $message = 'Для восстановления доступа к личному кабинету перейдите по ссылке http://rplusmgmt.com/api/account/confirm_restore?reg_code=' . $account->reg_code;
    send_email($email, $subject, $message);
    
    log_event('password restoration asked', $account->email);
    
    return $self->render(json => {status => 'ok'});
}

sub confirm_restore {
    my $self = shift;
    my $reg_code = $self->param('reg_code');

    my $account = Rplus::Model::Account::Manager->get_objects(query => [reg_code => $reg_code, del_date => undef])->[0];
    
    $self->flash(reg_code => $reg_code);
    
    log_event('password restoration confirmed', $account->email);
    
    return $self->redirect_to('/passwdrestore');
}

sub restore {
    my $self = shift;
    my $reg_code = $self->param('reg_code');    
    my $new_password = $self->param('new_password');

    my $account = Rplus::Model::Account::Manager->get_objects(query => [reg_code => $reg_code, del_date => undef])->[0];
    
    $account->password($new_password);
    $account->reg_code(generate_code());
    $account->save(changes_only => 1);
    
    $self->session->{'user'} = {
        id => $account->id,
        login => $account->email,
    };
    
    $self->flash(show_message => 1, title => 'RplusMgmt', message => '<p>Доступ к кабинету восстановлен</p>');
    
    log_event('password restored', $account->email);
    
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
        
        log_event('password changed', $account->email);
        
        return $self->render(json => {status => 'ok'});
    }
}

sub create {
    my $self = shift;

    # Create account
    my $account = Rplus::Model::Account->new;

    # Input params
    my $email = $self->param('email');
    my $password = $self->param('password');
    my $offer_type = $self->param('offer_type');
    my $location_id = $self->param('location_id');

    # Save
    $account->email($email);
    $account->password($password);    
    $account->reg_code(generate_code());
    $account->mode($offer_type);
    $account->location_id($location_id);

    eval {
        $account->save(insert => 1);
        1;
    } or do {
        return $self->render(json => {error => $@}, status => 500);
    };

    my $subject = 'Подтверждение регистрации RplusMgmt';
    my $message = 'Для подтверждения регистрации перейдите по ссылке http://rplusmgmt.com/api/account/confirm?reg_code=' . $account->reg_code;
    send_email($email, $subject, $message);
    
    log_event('account created', $email);
    
    return $self->render(json => {status => 'success', });
}

sub confirm {
    my $self = shift;
    #Mojo::IOLoop->stream($self->tx->connection)->timeout(6000);

    my $reg_code = $self->param('reg_code');
    my $account = Rplus::Model::Account::Manager->get_objects(query => [reg_code => $reg_code, del_date => undef])->[0];

    if (!$account) {
        $self->flash(
            show_message => 1, 
            title => 'Регистрация подтверждена', 
            message => '<p>Ваша регистрация подтверждена</p><p>Перейти в личный <a href="/cabinet">кабинет</a></p>',
        );
        return $self->redirect_to('/main');
    }

    eval {
        $account->reg_code(generate_code());
        $account->save(changes_only => 1);
        1;
    } or do {
        return $self->render(json => {error => $@}, status => 500);
    };

    $account->user_count('1');
    $account->balance('0');
    $account->name('account' . $account->id);
    $account->save(changes_only => 1);

    log_event('registration confirmed', $account->email);

    $self->session->{'user'} = {
        id => $account->id,
        login => $account->email,
    };

    my $tx;
    if ($account->location_id == 1) {
        $tx = $ua->get('http://ctrl.rplusmgmt.com/backdoor/create_account', form => {
            email => $account->email,
            name =>  $account->name,
            location_id => $account->location_id,
        });

        my $vars = {
            subdomain  => $account->name,
            port  => 19100,
        };

        my $input = 'lib/RplusCabinet/Controller/API/templates/template.rplusmgmt.com';
        my $output = '/etc/nginx/sites-enabled/' . $account->name . '.rplusmgmt.com';

        $template->process($input, $vars, $output) || log_event('filed to create ngnix record: ' . $template->error(), $account->email);

    } else {
        $tx = $ua->get('http://ctrl_kms.rplusmgmt.com/backdoor/create_account', form => {
            email => $account->email,
            name =>  $account->name,
            location_id => $account->location_id,
        });

        my $vars = {
            subdomain  => $account->name,
            port  => 19101,
        };

        my $input = 'lib/RplusCabinet/Controller/API/templates/template.rplusmgmt.com';
        my $output = '/etc/nginx/sites-enabled/' . $account->name . '.rplusmgmt.com';

        $template->process($input, $vars, $output) || log_event('filed to create ngnix record: ' . $template->error(), $account->email);

    }

    my $res;
    if (($res = $tx->success) && ($res->json->{'status'} eq 'success')) {
        log_event('instance created', $account->email);
        $self->flash(
            show_message => 1, 
            title => 'Регистрация ' . $account->email . ' подтверждена', 
            message => 'Аккаунт активирован, добро пожаловать!',
        );
    } else {
        log_event('failed to create instance', $account->email);
        $self->flash(
            show_message => 1, 
            title => 'Регистрация ' . $account->email . ' подтверждена', 
            message => 'При активации аккаунта произошла непредвиденная ошибка, обратитесь в службу поддержки',
        );
    }

    system('sudo service nginx restart &');
    return $self->redirect_to('/cabinet');
}

1;
