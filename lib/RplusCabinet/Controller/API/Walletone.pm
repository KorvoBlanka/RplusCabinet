package RplusCabinet::Controller::API::Walletone;

use Digest::MD5 qw(md5 md5_hex md5_base64);
use MIME::Base64;
use Encode qw(encode);
use Mojo::Base 'Mojolicious::Controller';

use Rplus::Model::Account;
use Rplus::Model::Account::Manager;
use Rplus::Model::Billing;
use Rplus::Model::Billing::Manager;

my $secret_key = "327b466554496e4e677652377750686578346c547a6b4348697430";

sub prepare {
    my $self = shift;

    my $account_id = $self->param('account_id');
    my $summ = $self->param('summ');

    my $bill = Rplus::Model::Billing->new;
    $bill->account_id($account_id);
    $bill->sum($summ);
    $bill->state(0);
    $bill->provider('walletone');
    $bill->save(insert => 1);
    
    my $inv_id = $bill->{id};    
    my $success_url = "http://rplusmgmt.com/api/walletone/success?InvId=$inv_id&OutSum=$summ";
    my $fail_url = "http://rplusmgmt.com/api/walletone/fail?InvId=$inv_id";
     
    my %fields; # Добавление полей формы в ассоциативный массив

    $fields{"WMI_MERCHANT_ID"}    = "112664092580";
    $fields{"WMI_PAYMENT_AMOUNT"} = $summ;
    $fields{"WMI_PAYMENT_NO"}     = $inv_id;
    $fields{"WMI_CURRENCY_ID"}    = "643";
    $fields{"WMI_DESCRIPTION"}    = encode_base64(encode('UTF-8','Оплата подписки RplusMgmt'), "");
    $fields{"WMI_SUCCESS_URL"}    = $success_url;
    $fields{"WMI_FAIL_URL"}       = $fail_url;
     
    # Формирование сообщения, путем объединения значений формы,
    # отсортированных по именам ключей в порядке возрастания.
     
    my $fieldValues = "";
     
    for my $key (sort { lc($a) cmp lc($b) } keys %fields)
    {
      $fieldValues .= $fields{$key};
    }
     
    # Формирование значения параметра WMI_SIGNATURE, путем
    # вычисления отпечатка, сформированного выше сообщения,
    # по алгоритму MD5 и представление его в Base64.
     
    my $signature = md5_base64(encode('cp1251', $fieldValues . $secret_key)) . '==';


    my $res = {
        inv_id => $inv_id,
        crc => $signature,
        out_sum => $summ,
        success_url => $success_url,
        fail_url => $fail_url,
    };

    return $self->render(json => $res);
}

sub result {
    my $self = shift;
    my $signature = $self->param('WMI_SIGNATURE');
    my $inv_id = $self->param('WMI_PAYMENT_NO');
    my $summ = $self->param('WMI_PAYMENT_AMOUNT');

    my $bill = Rplus::Model::Billing::Manager->get_objects(query => [id => $inv_id])->[0];
    # проверим счет
    if(!$bill) {
        return $self->render(text => 'WMI_RESULT=RETRY&WMI_DESCRIPTION=bill not found');
    }

    # проверим сумму
    if($bill->sum != $summ) {
        return $self->render(text => 'WMI_RESULT=RETRY&WMI_DESCRIPTION=wrong summ');
    }

    my $account = Rplus::Model::Account::Manager->get_objects(query => [id => $bill->{'account_id'}, del_date => undef])->[0];
    if (!$account) {
        return $self->render(text => 'WMI_RESULT=RETRY&WMI_DESCRIPTION=user not found');
    }

    $bill->state(1);    # state ok
    $bill->save(changes_only => 1);

    my $balance = $account->{'balance'} + $summ;

    $account->balance($balance);
    $account->save(changes_only => 1);

    return $self->render(text => 'WMI_RESULT=OK');
}

sub success {
    my $self = shift;

    my $inv_id = $self->param('InvId');
    my $summ = $self->param('OutSum');

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
    
    my $bill = Rplus::Model::Billing::Manager->get_objects(query => [id => $inv_id])->[0];
    if ($bill) {
        $bill->state(2);    # state fail
        $bill->save(changes_only => 1);
    }
    
    $self->flash(show_message => 1, message => 'Платеж не принят');
    return $self->redirect_to('/cabinet');
}

1;
