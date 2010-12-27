package Dist::Zilla::PluginBundle::OLIVER;

use Moose;
with 'Dist::Zilla::Role::PluginBundle::Easy';

# if set, trigger FakeRelease instead of UploadToCPAN
has no_cpan => (
  is      => 'ro',
  isa     => 'Bool',
  lazy    => 1,
  default => sub { $ENV{NO_CPAN} || $_[0]->payload->{no_cpan} }
);

sub configure {
    my $self = shift;

    $self->add_plugins(qw/
        MetaResourcesFromGit
        ReadmeFromPod
    /);

    my %basic_opts = (
        '-bundle' => '@Basic',
        '-remove' => [ 'Readme' ],
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
        'branch' => '',
        'release_branch' => 'master',
        'message' => ($self->_get_changes
            || 'Build results of %h (on %b)'),
    }]);

    $self->add_bundle('@Git' => {
        'commit_msg' => 'Bumped changelog following rel. v%v'
    });
}

# stolen from Dist::Zilla::Plugin::Git::Commit
sub _get_changes {
    my $self = shift;

    # parse changelog to find commit message
    my $changelog = Dist::Zilla::File::OnDisk->new( { name => 'Changes' } );
    my $newver    = '{{\$NEXT}}';
    my @content   =
        grep { /^$newver(?:\s+|$)/ ... /^\S/ } # from newver to un-indented
        split /\n/, $changelog->content;
    shift @content; # drop the version line
    # drop unindented last line and trailing blank lines
    pop @content while ( @content && $content[-1] =~ /^(?:\S|\s*$)/ );

    # return commit message
    return join("\n", @content, ''); # add a final \n
} # end _get_changes

__PACKAGE__->meta->make_immutable;
no Moose;
1;

# ABSTRACT: Dists like OLIVER's

=head1 DESCRIPTION

This is the plugin bundle that OLIVER uses. It is equivalent to:

 [MetaResourcesFromGit]
  
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

If you provide the C<no_cpan> option with a true value to the bundle, or set
the environment variable C<NO_CPAN> to a true value, then the upload to CPAN
will be suppressed.

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
