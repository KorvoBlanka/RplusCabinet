package RplusCabinet;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Plugins
  $self->plugin('Config' => {file => 'app.conf'});

  #
  $self->hook(before_routes => sub {
      my $c = shift;
      say 'before_routes';
  });

  # Router
  my $r = $self->routes;

  # API namespace
  $r->route('/api/:controller')->under->to(cb => sub {
      my $self = shift;
      return 1;
  })->route('/:action')->to(namespace => 'RplusCabinet::Controller::API');

  # Base namespace
  my $r2 = $r->route('/')->to(namespace => 'RplusCabinet::Controller');
  {
      # Authentication
      $r2->post('/signin')->to('authentication#signin');
      $r2->get('/signout')->to('authentication#signout');

      # auth protected controllers
      my $r2b = $r2->under->to(controller => 'authentication', action => 'auth');
      $r2b->get('/cabinet')->to(controller => 'cabinet', action => 'index');

      # Main controller
      $r2->get('/')->to(controller => 'main', action => 'index');
      # Other controllers
      $r2->get('/:controller/:action')->to(action => 'index');

  }
}

1;
