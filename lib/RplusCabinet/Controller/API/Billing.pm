package RplusCabinet::Controller::API::Billing;

use Digest::MD5 qw(md5_hex);
use Mojo::Base 'Mojolicious::Controller';

use Rplus::Model::Account;
use Rplus::Model::Account::Manager;
use Rplus::Model::Billing;
use Rplus::Model::Billing::Manager;


my $mrch_login = "rplusmgmt";
my $mrch_pass1 = "password1";
my $mrch_pass2 = "password2";

sub prepare {
    my $self = shift;

    my $account_id = $self->param('account_id');
    my $summ = $self->param('summ');

    my $bill = Rplus::Model::Billing->new;
    $bill->account_id($account_id);
    $bill->sum($summ);
    $bill->state(0);
    $bill->provider('robokassa');
    $bill->save(insert => 1);
    
    my $inv_id = $bill->{id};
    my $crc = md5_hex("$mrch_login:$summ:$inv_id:$mrch_pass1");
    
    my $res = {
        inv_id => $inv_id,
        crc => $crc,
    };

    return $self->render(json => $res);
}

sub result {
    my $self = shift;
    my $signature = $self->param('SignatureValue');
    my $inv_id = $self->param('InvId');
    my $summ = $self->param('OutSum');

    # Проверить CRC
    my $crc = uc(md5_hex("$summ:$inv_id:$mrch_pass2"));
    if($crc ne $signature) {
        return $self->render(text => "FAIL crc");
    }

    my $bill = Rplus::Model::Billing::Manager->get_objects(query => [id => $inv_id])->[0];
    # проверим счет
    if(!$bill) {
        return $self->render(text => 'FAIL');
    }

    # проверим сумму
    if($bill->sum != $summ) {
        return $self->render(text => 'FAIL');   
    }

    my $account = Rplus::Model::Account::Manager->get_objects(query => [id => $bill->{'account_id'}, del_date => undef])->[0];
    if (!$account) {
        return $self->render(text => 'FAIL');
    }

    $bill->state(1);    # state ok
    $bill->save(changes_only => 1);

    my $balance = $account->{'balance'} + $summ;
    $account->balance($balance);
    $account->save(changes_only => 1);

    return $self->render(text => 'OK' . $inv_id);
}

sub success {
    my $self = shift;

    my $signature = $self->param('SignatureValue');
    my $inv_id = $self->param('InvId');
    my $summ = $self->param('OutSum');

    # Проверить CRC
    my $crc = md5_hex("$summ:$inv_id:$mrch_pass1");
    if($crc ne $signature) {
        $self->flash(show_message => 1, message => "Не верная подпись. Обратитесь в службу поддержки.");
        return $self->redirect_to('/cabinet');
    }

    my $bill = Rplus::Model::Billing::Manager->get_objects(query => [id => $inv_id])->[0];
    # проверим 
    if(!$bill) {
        $self->flash(show_message => 1, message => "Не найден счет. Обратитесь в службу поддержки.");
        return $self->redirect_to('/cabinet');
    }

    my $account = Rplus::Model::Account::Manager->get_objects(query => [id => $bill->{'account_id'}, del_date => undef])->[0];
    if (!$account) {
        $self->flash(show_message => 1, message => "Не найдена учетная запись. Обратитесь в службу поддержки.");
    }

    $self->flash(show_message => 1, message => 'Платеж успешно принят. На счет зачислено '. $summ . ' рублей');
    return $self->redirect_to('/cabinet');
}

sub fail {
    my $self = shift;

    my $inv_id = $self->param('InvId');
    my $sum = $self->param('OutSum');
    
    my $bill = Rplus::Model::Billing::Manager->get_objects(query => [id => $inv_id])->[0];
    if ($bill) {
        $bill->state(2);    # state fail
        $bill->save(changes_only => 1);
    }
    
    $self->flash(show_message => 1, message => 'Платеж не принят');
    return $self->redirect_to('/cabinet');
}

1;
