package Socialtext::Resting;

use strict;
use warnings;

use URI::Escape;
use LWP::UserAgent;
use HTTP::Request;
use Class::Field 'field';

use Readonly;

our $VERSION = '0.02';

=head1 NAME

Socialtext::Resting - module for accessing Socialtext REST APIs

=head1 SYNOPSIS

  use Socialtext::Resting;
  my $Rester = Socialtext::Resting->new(
    username => $opts{username},
    password => $opts{password},
    server   => $opts{server},
  );
  $Rester->workspace('wikiname');
  $Rester->get_page('my_page');
}

=head1 DESCRIPTION

C<Socialtext::Resting> is a module designed to allow remote access
to the Socialtext REST APIs for use in perl programs.

=head1 METHODS

=cut

Readonly my $BASE_URI => '/data/workspaces';
Readonly my %ROUTES   => (
    page           => $BASE_URI . '/:ws/pages/:pname',
    pages          => $BASE_URI . '/:ws/pages',
    pagetag        => $BASE_URI . '/:ws/pages/:pname/tags/:tag',
    pagetags       => $BASE_URI . '/:ws/pages/:pname/tags',
    pageattachment => $BASE_URI
        . '/:ws/pages/:pname/attachments/:attachment_id',
    pageattachments      => $BASE_URI . '/:ws/pages/:pname/attachments',
    workspace            => $BASE_URI . '/:ws',
    workspaces           => $BASE_URI,
    workspacetag         => $BASE_URI . '/:ws/tags/:tag',
    workspacetags        => $BASE_URI . '/:ws/tags',
    workspaceattachment  => $BASE_URI . '/:ws/attachments/:attachment_id',
    workspaceattachments => $BASE_URI . '/:ws/attachments',
    workspaceuser        => $BASE_URI . '/:ws/users/:user_id',
    workspaceusers       => $BASE_URI . '/:ws/users',
    user                 => '/data/users/:user_id',
    users                => '/data/users',
);

field 'workspace';
field 'username';
field 'password';
field 'server';
field 'accept';
field 'filter';
field 'order';
field 'count';
field 'query';

=head2 new

    my $Rester = Socialtext::Resting->new(
        username => $opts{username},
        password => $opts{password},
        server   => $opts{server},
    );
    
    Creates a Socialtext::Resting object for the 
    specified server/user/password combination.

=cut

sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = {@_};
    return bless $self, $class;
}

=head2 get_page 

    $Rester->workspace('wikiname');
    $Rester->get_page('page_name');

    Retrieves the content of the specified page.  Note that 
    the workspace method needs to be called first to specify 
    which workspace to operate on.

=cut

sub get_page {
    my $self = shift;
    my $pname = shift;
    my $accept = $self->accept || 'text/x.socialtext-wiki';

    my $uri = $self->_make_uri(
        'page',
        { pname => $pname, ws => $self->workspace }
    );

    my ( $status, $content ) = $self->_request(
        uri    => $uri,
        method => 'GET',
        accept => $accept,
    );

    if ( $status == 200 || $status == 404 ) {
        return $content;
    }
    else {
        die "$status: $content\n";
    }
}

=head2 get_attachment

    $Rester->workspace('wikiname');
    $Rester->get_attachment('attachment_id);

    Retrieves the specified attachment from the workspace.  
    Note that the workspace method needs to be called first 
    to specify which workspace to operate on.

=cut

# REVIEW: dup with above, some
sub get_attachment {
    my $self          = shift;
    my $attachment_id = shift;

    my $uri = $self->_make_uri(
        'workspaceattachment',
        { attachment_id => $attachment_id, ws => $self->workspace, }
    );

    my ( $status, $content ) = $self->_request(
        uri    => $uri,
        method => 'GET',
    );

    if ( $status == 200 || $status == 404 ) {
        return $content;
    }
    else {
        die "$status: $content\n";
    }
}

=head2 put_pagetag

    $Rester->workspace('wikiname');
    $Rester->put_pagetag('page_name', 'tag');

    Add the specified tag to the page.

=cut

sub put_pagetag {
    my $self  = shift;
    my $pname = shift;
    my $tag   = shift;

    my $uri = $self->_make_uri(
        'pagetag',
        { pname => $pname, ws => $self->workspace, tag => $tag }
    );

    my ( $status, $content ) = $self->_request(
        uri    => $uri,
        method => 'PUT',
    );

    if ( $status == 204 || $status == 201 ) {
        return $content;
    }
    else {
        die "$status: $content\n";
    }
}

=head2 delete_pagetag

    $Rester->workspace('wikiname');
    $Rester->delete_pagetag('page_name', 'tag');

    Delete the specified tag from the page.

=cut

sub delete_pagetag {
    my $self  = shift;
    my $pname = shift;
    my $tag   = shift;

    my $uri = $self->_make_uri(
        'pagetag',
        { pname => $pname, ws => $self->workspace, tag => $tag }
    );

    my ( $status, $content ) = $self->_request(
        uri    => $uri,
        method => 'DELETE',
    );

    if ( $status == 204 ) {
        return $content;
    }
    else {
        die "$status: $content\n";
    }
}

=head2 post_attachment

    $Rester->workspace('wikiname');
    $Rester->post_attachment('page_name',$id,$content,$mime_type);

    Attach the file to the specified page

=cut

sub post_attachment {
    my $self               = shift;
    my $pname              = shift;
    my $attachment_id      = shift;
    my $attachment_content = shift;
    my $attachment_type    = shift;

    my $uri = $self->_make_uri(
        'pageattachments',
        {
            pname => $pname,
            ws    => $self->workspace
        },
    );

    $uri .= "?name=$attachment_id";

    my ( $status, $content, $location ) = $self->_request(
        uri     => $uri,
        method  => 'POST',
        type    => $attachment_type,
        content => $attachment_content,
    );

    $location =~ m{.*/attachments/([^/]+)};
    $location = URI::Escape::uri_unescape($1);

    if ( $status == 204 || $status == 201 ) {
        return $location;
    }
    else {
        die "$status: $content\n";
    }
}

=head2 put_page 

    $Rester->workspace('wikiname');
    $Rester->put_page('page_name',$content);

    Save the content as a page in the wiki.

=cut

sub put_page {
    my $self         = shift;
    my $pname        = shift;
    my $page_content = shift;

    my $uri = $self->_make_uri(
        'page',
        { pname => $pname, ws => $self->workspace }
    );

    my ( $status, $content ) = $self->_request(
        uri     => $uri,
        method  => 'PUT',
        type    => 'text/x.socialtext-wiki',
        content => $page_content,
    );

    if ( $status == 204 || $status == 201 ) {
        return $content;
    }
    else {
        die "$status: $content\n";
    }
}

sub _make_uri {
    my $self         = shift;
    my $thing        = shift;
    my $replacements = shift;

    my $uri = $ROUTES{$thing};

    # REVIEW: tried to do this in on /g go but had issues where
    # syntax errors were happening...
    foreach my $stub ( keys(%$replacements) ) {
        my $replacement
            = URI::Escape::uri_escape_utf8( $replacements->{$stub} );
        $uri =~ s{/:$stub\b}{/$replacement};
    }

    return $uri;
}

=head2 get_pages 

    $Rester->workspace('wikiname');
    $Rester->get_pages();

    List all pages in the wiki.

=cut

sub get_pages {
    my $self = shift;

    return $self->_get_things('pages');
}

sub _extend_uri {
    my $self = shift;
    my $uri = shift;
    my @extend;

    if ( $self->filter ) {
        push (@extend, "filter=" . $self->filter);
    }
    if ( $self->query ) {
        push (@extend, "q=" . $self->query);
    }
    if ( $self->order ) {
        push (@extend, "order=" . $self->order);
    }
    if ( $self->count ) {
        push (@extend, "count=" . $self->count);
    }
    if (@extend) {
        $uri .= "?" . join(';', @extend);
    }
    return $uri;

}
sub _get_things {
    my $self         = shift;
    my $things       = shift;
    my %replacements = @_;
    my $accept = $self->accept || 'text/plain';

    my $uri = $self->_make_uri(
        $things,
        { ws => $self->workspace, %replacements }
    );
    $uri = $self->_extend_uri($uri);
       
    my ( $status, $content ) = $self->_request(
        uri    => $uri,
        method => 'GET',
        accept => $accept,
    );

    if ( $status == 200 ) {
        return ( grep defined, ( split "\n", $content ) );
    }
    elsif ( $status == 404 ) {
        return ();
    }
    else {
        die "$status: $content\n";
    }
}

sub get_pagetag {
}

=head2 get_pagetags

    $Rester->workspace('wikiname');
    $Rester->get_pagetags('page_name');

    List all pagetags on the specified page 

=cut

sub get_pagetags {
    my $self  = shift;
    my $pname = shift;

    return $self->_get_things( 'pagetags', pname => $pname );
}

=head2 get_workspaces

    $Rester->get_workspaces();

    List all workspaces on the server

=cut

sub get_workspaces {
    my $self = shift;

    return $self->_get_things('workspaces');
}

sub _request {
    my $self = shift;
    my %p    = @_;
    my $ua   = LWP::UserAgent->new();
    my $uri  = $self->server . $p{uri};
    warn "uri: $uri\n";
    my $request = HTTP::Request->new( $p{method}, $uri );
    $request->authorization_basic( $self->username, $self->password );

    $request->header( 'Accept'       => $p{accept} ) if $p{accept};
    $request->header( 'Content-Type' => $p{type} )   if $p{type};
    $request->content( $p{content} ) if $p{content};

    my $response = $ua->simple_request($request);

    my $location = $response->header('location');

    return ( $response->code, $response->content, $location );
}

=head1 AUTHORS

Chris Dent, C<< <chris.dent@socialtext.com> >>
Kirsten Jones C<< <kirsten.jones@socialtext.com> >>

1;
