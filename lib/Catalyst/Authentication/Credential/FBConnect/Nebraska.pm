package Catalyst::Authentication::Credential::FBConnect::Nebraska;

use Moose;
use feature qw( :5.10 );
use MooseX::Types::Moose qw/ Bool /;
use MooseX::Types::Common::String qw/ NonEmptySimpleStr /;
use WWW::Facebook::API;
use Catalyst::Exception ();
use namespace::autoclean;

# ABSTRACT: Facebook credential for Catalyst::Plugin::Authentication framework.
# VERSION

has debug => ( is => 'ro', isa => Bool, );
has api_key => ( is => 'ro', isa => NonEmptySimpleStr, required => 1 );
has secret => ( is => 'ro', isa => NonEmptySimpleStr, required => 1 );
has app_name => ( is => 'ro', isa => NonEmptySimpleStr, required => 1 );
has fbconnect => ( is => 'ro', lazy_build => 1, init_arg => undef, isa => 'WWW::Facebook::API' );

sub BUILDARGS {
	my ($class, $config, $c, $realm) = @_;

    return $config;
}

sub BUILD {
    my ($self) = @_;
    $self->fbconnect; # Ensure lazy value is built.
}

sub _build_fbconnect {
    my $self = shift;

	WWW::Facebook::API->new(
		desktop => 0,
		map { $_ => $self->$_() } qw/ app_name api_key secret /
	);
}

sub authenticate {
	my ($self, $c, $realm, $auth_info) = @_;

	my $token = $c->req->method eq 'GET'
		? $c->req->query_params->{'auth_token'}
		: $c->req->body_params->{'auth_token'};

	if( defined $token ) {

		$self->fbconnect->auth->get_session( $token );

		my $user = +{
			session_uid => $self->fbconnect->session_uid,
			#session_key => $self->fbconnect->session_key,
			#session_expires => $self->fbconnect->session_expires
		};

		my $user_obj = $realm->find_user( $user, $c );
		
		if(ref $user_obj)
		{
		  warn "ref user_obj = ", ref $user_obj, "\n";
		  # update session_key 
		  # and    session_expires
		  # c.user.get_object
		  my $user =$user_obj->get_object;
		  $user->session_key($self->fbconnect->session_key);
		  $user->session_expires($self->fbconnect->session_expires);
		  $user->update;
		  return $user_obj;
		}

		$c->log->debug( 'Verified FBConnect::Nebraska itentity failed' ) if $self->debug;

		return;
	}
	else {
		$c->res->redirect( $self->fbconnect->get_login_url( next => $c->uri_for( $c->action, $c->req->captures, @{ $c->req->args } ) ) );
	}

}

1;

__END__

=head1 DESCRIPTION

This is a fork of the original for my specific application, The Nebraska Project.

=head1 SYNOPSIS

In MyApp.pm

 use Catalyst qw/
      Authentication
      Session
      Session::Store::FastMmap
      Session::State::Cookie
 /;


In myapp.conf

    <Plugin::Authentication>
        default_realm	facebook
        <realms>
            <facebook>
                <credential>
                    class       FBConnect::Nebraska
                    api_key     my_app_key
                    secret      my_app_secret
                    app_name    my_app_name
                </credential>
            </facebook>
        </realms>
    </Plugin::Authentication>


In controller code,

  sub facebook : Local {
       my ($self, $c) = @_;

       if( $c->authenticate() ) {
             #do something with $c->user
       }
  }



=head1 USER METHODS

=over 4

=item $c->user->session_uid

=item $c->user->session_key

=item $c->user->session_expires

=back

=head1 AUTHOR

Fork by

=over 4

=item Graham Ollis E<lt>plicease@cpan.orgE<gt>

=back

Original by

=over 4

=item Cosmin Budrica E<lt>cosmin@sinapticode.comE<gt>

=item Bogdan Lucaciu E<lt>bogdan@sinapticode.comE<gt>

=item With contributions from:

Tomas Doran E<lt>bobtfish@bobtfish.netE<gt>

=back

=cut
