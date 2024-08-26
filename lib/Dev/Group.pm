# --
# Copyright (C) 2022 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Dev::Group;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DB',
    'Kernel::System::Cache',
    'Kernel::System::Group',
    'Kernel::System::Log',
);

=head1 NAME

Dev::Group - Ticket Group Dev lib

=head1 SYNOPSIS

All Ticket Group Development functions.

=head1 PUBLIC INTERFACE

=head2 new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $ValidObject = $Kernel::OM->Get('Dev::Group');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # 0=off; 1=on;
    $Self->{Debug} = $Param{Debug} || 0;

    # set lower if database is case sensitive
    $Self->{Lower} = '';
    if ( $Kernel::OM->Get('Kernel::System::DB')->GetDatabaseFunction('CaseSensitive') ) {
        $Self->{Lower} = 'LOWER';
    }

    return $Self;
}

=head2 GroupDelete()

Deletes a ticket Group from DB

    my $Success = $DevGroupObject->GroupDelete(
        GroupID => 123,                      # GroupID or Group is required
        Group   => 'Some Group',
    );

Returns:
    $Success = 1;                           # or false if there was any error.

=cut

sub GroupDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Group} && !$Param{GroupID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need User or UserID!'
        );
        return;
    }

    # get group object
    my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');

    # set GroupID
    my $GroupID = $Param{GroupID} || '';
    if ( !$GroupID ) {
        $GroupID = $GroupObject->GroupLookup(
            Group => $Param{Group},
        );
    }
    if ( !$GroupID ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Group is invalid!'
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # delete Group User relations
    return if !$DBObject->Do(
        SQL => "
            DELETE FROM group_user
            WHERE group_id = ?",
        Bind  => [ \$GroupID ],
        Limit => 1,
    );

    # delete Group Role relations
    return if !$DBObject->Do(
        SQL => "
            DELETE FROM group_role
            WHERE group_id = ?",
        Bind  => [ \$GroupID ],
        Limit => 1,
    );

    my $GroupTable = 'group';

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my $Version = $ConfigObject->Get('Version');
    my ($MajorVersion) = $Version =~ m{\A(\d+)\.}msx;

    if ( $MajorVersion >= 7 ) {
        $GroupTable = 'groups_table';
    }

    # delete Group from DB
    return if !$DBObject->Do(
        SQL => "
            DELETE FROM $GroupTable
            WHERE id = ?",
        Bind  => [ \$GroupID ],
        Limit => 1,
    );

    # delete cache
    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');
    $CacheObject->Delete(
        Type => 'Group',
        Key  => 'GroupDataList',
    );
    $CacheObject->Delete(
        Type => 'Group',
        Key  => 'GroupList::0',
    );
    $CacheObject->Delete(
        Type => 'Group',
        Key  => 'GroupList::1',
    );
    $CacheObject->CleanUp(
        Type => 'CustomerGroup',
    );
    $CacheObject->CleanUp(
        Type => 'GroupPermissionUserGet',
    );
    $CacheObject->CleanUp(
        Type => 'GroupPermissionGroupGet',
    );
    return 1;
}

=head2 GroupSearch()

To search Groups

    my %List = $DevGroupObject->GroupSearch(
        Name  => '*some*', # also 'hans+huber' possible
        Valid => 1,        # not required
    );

=cut

sub GroupSearch {
    my ( $Self, %Param ) = @_;

    my %Groups;
    my $Valid = defined $Param{Valid} ? $Param{Valid} : 1;

    # check needed stuff
    if ( !$Param{Name} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Name!',
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # get like escape string needed for some databases (e.g. oracle)
    my $LikeEscapeString = $DBObject->GetDatabaseFunction('LikeEscapeString');

    # build SQL string 1/2
    my $SQL = '
        SELECT id, name
        FROM groups
        WHERE';

    # build SQL string 2/2
    $Param{Name} =~ s/\*/%/g;
    $SQL .= ' name LIKE '
        . "'" . $DBObject->Quote( $Param{Name}, 'Like' ) . "'"
        . "$LikeEscapeString";

    # add valid option
    if ($Valid) {
        $SQL .= " AND valid_id IN (" . join( ', ', $Self->{ValidObject}->ValidIDsGet() ) . ")";
    }

    # get data
    return if !$DBObject->Prepare(
        SQL   => $SQL,
        Limit => $Param{Limit},
    );

    # fetch the result
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Groups{ $Row[0] } = $Row[1];
    }

    return %Groups;
}

1;
