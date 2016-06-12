package RplusCabinet::Controller::API::Googleauth;

use Digest::MD5 qw(md5_hex);
use Mojo::Base 'Mojolicious::Controller';
use Mojo::UserAgent;
use JSON;

use Data::Dumper;


my $CLIENT_ID = '18830375155-q1bh1fhapui07fp7drs6fcgp4vca4hn4.apps.googleusercontent.com';
my $CLIENT_SECRET = 'VZKzvmy9uqJRIx2ziuOFo2xF';
my $REDIRECT_URI = 'http://rplusmgmt.com/api/googleauth/callback';

my $ua = Mojo::UserAgent->new;
$ua->max_redirects(4);

sub callback {
    my $self = shift;
    my $state = $self->param('state');
    my $GCODE = $self->param('code');

    my $url = "https://accounts.google.com/o/oauth2/token";

    my $tx = $ua->post($url, {
            'Content-Type' => 'application/x-www-form-urlencoded',
        }, form => {
            redirect_uri => $REDIRECT_URI,
            client_id => $CLIENT_ID,
            client_secret => $CLIENT_SECRET,
            code => $GCODE,
            grant_type => 'authorization_code',
        }
    );

    my $asset;
    my $refresh_token = '';
    if (my $res = $tx->success) {
      $asset = decode_json $res->content->asset->{content};
      $refresh_token = $asset->{refresh_token};
    }

    my ($user_id, $domain) = split '@', $state;

    $tx = $ua->post('http://' . $domain . '/api/user/set_google_token', form => {
      id => $user_id,
      refresh_token => $refresh_token,
    });

    my $tx_str = Dumper $tx;

    my $template = <<"END_MSG";

<!DOCTYPE html>
<html>
    <head>
        <script type="application/javascript">
            //console.log('$refresh_token');
            // послать сообщение родительскому окну. а что если мы на планшете?
            //window.opener.postMessage({refresh_token: '$refresh_token'}, '*');
            window.close();
        </script>
    </head>
    <body>
        Это окно можно закрыть
    </body>
</html>
END_MSG


    $self->render(inline => $template);
}

1;