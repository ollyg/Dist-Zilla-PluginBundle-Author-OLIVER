package Dist::Zilla::PluginBundle::OLIVER;

use Moose;
with 'Dist::Zilla::Role::PluginBundle::Easy';

use Dist::Zilla::PluginBundle::Basic;
use Dist::Zilla::PluginBundle::Git;

# both available due to Dist::Zilla
use Path::Class 'dir';
use Config::INI::Reader;

# if set, trigger FakeRelease instead of UploadToCPAN
has no_cpan => (
  is      => 'ro',
  isa     => 'Bool',
  lazy    => 1,
  default => sub { $_[0]->payload->{no_cpan} }
);

has account => (
  is      => 'ro',
  isa     => 'Str',
  lazy    => 1,
  default => sub { $_[0]->_find_account }
);

sub _find_account {
    my $self = shift;

    my $root = dir($ARGV[0] || '.git');
    my $ini = $root->file('config');

    die "OLIVER: this bundle needs a .git/config file, and you don't have one\n"
        unless -e $ini;

    my $fh = $ini->openr;
    my $config = Config::INI::Reader->read_handle($fh);

    die "OLIVER: no 'origin' remote found in .git/config\n"
        unless exists $config->{'remote "origin"'};

    my $url = $config->{'remote "origin"'}->{'url'};
    die "OLIVER: no url found for remote 'origin'\n"
        unless $url and length $url;

    my $dist = $self->dist;
    my ($account) = ($url =~ m{[:/](.+)/$dist.git$});

    die "OLIVER: no github account name found in .git/config\n"
        unless $account and length $account;

    return $account;
}

has dist => (
  is      => 'ro',
  isa     => 'Str',
  lazy    => 1,
  default => sub { $_[0]->_find_dist }
);

sub _find_dist {
    my $root = dir($ARGV[0] || '.');
    my $ini = $root->file('dist.ini');

    die "OLIVER: this bundle needs a dist.ini file, and you don't have one\n"
        unless -e $ini;

    my $fh = $ini->openr;
    my $config = Config::INI::Reader->read_handle($fh);
    my $dist = $config->{'_'}->{'dist'};

    die "OLIVER: no dist option found in dist.ini\n"
        unless $dist and length $dist;

    return $dist;
}

sub configure {
    my $self = shift;

    my $dist    = $self->dist;
    my $account = $self->account;

    $self->add_plugins([ 'MetaResources' => {
        'homepage'
            => "http://github.com/$account/$dist/wiki",
        'bugtracker.web'
            => "https://rt.cpan.org/Public/Dist/Display.html?Name=$dist",
        'repository.url'
            => "git://github.com/$account/$dist.git",
    }]);

    $self->add_plugins('ReadmeFromPod');

    my %basic_opts = (
        '-bundle' => '@Basic',
        '-remove' => 'Readme',
    );

    if ($self->no_cpan) {
        $basic_opts{'-remove'}
            = [ 'Readme', 'UploadToCPAN' ];
        $self->add_plugins('FakeRelease');
    }

    $self->add_bundle('@Filter' => \%basic_opts);

    $self->add_plugins(qw/
        AutoVersion
        NextRelease
        PkgVersion
        PodWeaver
        AutoPrereqs
    /);

    $self->add_plugins([ 'PruneFiles' => {
        'filenames' => 'dist.ini'
    }]);

    # CommitBuild -must- come before @Git
    $self->add_plugins([ 'Git::CommitBuild' => {
        'branch' => undef,
        'release_branch' => 'master',
    }]);

    $self->add_bundle('@Git' => {
        'commit_msg' => '%c'
    });
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

# ABSTRACT: BeLike::OLIVER when you build your dists

=head1 DESCRIPTION

The is the plugin bundle that OLIVER uses. It is equivalent to:

 [MetaResources]
 homepage       = http://github.com/<ACCOUNT>/<DIST>/wiki
 bugtracker.web = https://rt.cpan.org/Public/Dist/Display.html?Name=<DIST>
 repository.url = git://github.com/<ACCOUNT>/<DIST>.git
 
 [ReadmeFromPod]
 [@Filter]
 -bundle = @Basic
 -remove = Readme
 
 [AutoVersion]
 [NextRelease]
 [PkgVersion]
 [PodWeaver]
 [AutoPrereqs]
 
 [PruneFiles]
 filenames = dist.ini
 
 [Git::CommitBuild]
 branch =
 release_branch = master

 [@Git]
 commit_msg = %c

=head1 CONFIGURATION

In the above, C<< <DIST> >> will be substituted for the value of the C<name>
option in your C<dist.ini> file. Also, C<< <ACCOUNT> >> will be substituted
for your L<http://github.com> account name. Both of these can be overriden
by providing the C<dist> or C<account> options to this Bundle in C<dist.ini>.

If you provide the C<no_cpan> option with a true value to the bundle, then
the upload to CPAN will be suppressed.

=head1 TIPS

Do not include a C<NAME>, C<VERSION>, C<AUTHOR> or C<LICENSE> POD section in
your code, they will be provided automatically. However please do include an
abstract for documented libraries via a comment like so:

 # ABSTRACT: here is my abstract statement

The bundle is desgined for projects which are hosted on C<github>. More so,
the project should have a C<master> branch which is where the I<built> code
is committed, and a I<separate> branch where you do code development. The
module author uses a C<devel> branch for this purpose. On C<github> you can
then leave the C<master> branch as the default branch for web browsing.

=cut
