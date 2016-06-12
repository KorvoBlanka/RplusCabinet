package RplusCabinet::Controller::Authentication;

use Mojo::Base 'Mojolicious::Controller';

use Rplus::Model::Account;
use Rplus::Model::Account::Manager;
use Data::Dumper;


sub auth {
    my $self = shift;

    return 1 if $self->session('user') && $self->session('user')->{'id'};

    $self->render(template => 'authentication/signin');
    return undef;
}

sub signin {
    my $self = shift;

    my $email = $self->param('email');
    my $password = $self->param('password');
    my $remember_me = $self->param('remember_me');

    return $self->render(json => {status => 'failed'}) unless $email && defined $password;

    my $user = Rplus::Model::Account::Manager->get_objects(query => [email => $email, password => $password, del_date => undef])->[0];
    return $self->render(json => {status => 'failed'}) unless $user;

    $self->session->{'user'} = {
        id => $user->id,
        login => $user->email,
    };
    
    if ($remember_me) {
        $self->session(expiration => 604800);
    } else {
        $self->session(expiration => 3600); # default expiration
    }

    return $self->render(json => {status => 'success'});
}

sub signout {
    my $self = shift;

    delete $self->session->{'user'};

    return $self->redirect_to('/');
}

1;
