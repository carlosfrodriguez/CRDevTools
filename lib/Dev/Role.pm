# --
# Copyright (C) 2020 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Dev::Role;

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

Dev::Role - Ticket Role Dev lib

=head1 SYNOPSIS

All Role Development functions.

=head1 PUBLIC INTERFACE

=head2 new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $RoleObject = $Kernel::OM->Get('Dev::Role');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    $Self->{Debug} = $Param{Debug} || 0;

    # Set lower if database is case sensitive.
    $Self->{Lower} = '';
    if ( $Kernel::OM->Get('Kernel::System::DB')->GetDatabaseFunction('CaseSensitive') ) {
        $Self->{Lower} = 'LOWER';
    }

    return $Self;
}

=head2 RoleDelete()

Deletes a Role from DB

    my $Success = $DevGroupObject->RoleDelete(
        RoleID => 123,                      # RoleID or Role is required
        Role   => 'Some Role',
    );

Returns:
    $Success = 1;                           # or false if there was any error.

=cut

sub RoleDelete {
    my ( $Self, %Param ) = @_;

    if ( !$Param{Role} && !$Param{RoleID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Role or RoleID!'
        );
        return;
    }

    my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');

    my $RoleID = $Param{RoleID} || '';
    if ( !$RoleID ) {
        $RoleID = $GroupObject->RoleLookup(
            Group => $Param{Group},
        );
    }
    if ( !$RoleID ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Role is invalid!'
        );
        return;
    }

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # Delete Role User relations.
    return if !$DBObject->Do(
        SQL => "
            DELETE FROM role_user
            WHERE role_id = ?",
        Bind  => [ \$RoleID ],
        Limit => 1,
    );

    # Delete Group Role relations.
    return if !$DBObject->Do(
        SQL => "
            DELETE FROM group_role
            WHERE role_id = ?",
        Bind  => [ \$RoleID ],
        Limit => 1,
    );

    # Delete Group from DB.
    return if !$DBObject->Do(
        SQL => "
            DELETE FROM roles
            WHERE id = ?",
        Bind  => [ \$RoleID ],
        Limit => 1,
    );

    # Delete cache.
    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');
    $CacheObject->Delete(
        Type => 'Group',
        Key  => 'RoleDataList',
    );
    $CacheObject->Delete(
        Type => 'Group',
        Key  => 'RoleList::0',
    );
    $CacheObject->Delete(
        Type => 'Group',
        Key  => 'RoleList::1',
    );
    $CacheObject->CleanUp(
        Type => 'DBGroupRoleGet',
    );
    return 1;
}

=head2 RoleSearch()

To search Roles

    my %List = $DevGroupObject->RoleSearch(
        Name  => '*some*', # also 'hans+huber' possible
        Valid => 1,        # not required
    );

=cut

sub RoleSearch {
    my ( $Self, %Param ) = @_;

    my %Roles;
    my $Valid = defined $Param{Valid} ? $Param{Valid} : 1;

    if ( !$Param{Name} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Name!',
        );
        return;
    }

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # Get like escape string needed for some databases (e.g. oracle).
    my $LikeEscapeString = $DBObject->GetDatabaseFunction('LikeEscapeString');

    # Build SQL string 1/2.
    my $SQL = '
        SELECT id, name
        FROM roles
        WHERE';

    # Build SQL string 2/2.
    $Param{Name} =~ s/\*/%/g;
    $SQL .= ' name LIKE '
        . "'" . $DBObject->Quote( $Param{Name}, 'Like' ) . "'"
        . "$LikeEscapeString";

    # Ddd valid option.
    if ($Valid) {
        $SQL .= " AND valid_id IN (" . join( ', ', $Self->{ValidObject}->ValidIDsGet() ) . ")";
    }

    return if !$DBObject->Prepare(
        SQL   => $SQL,
        Limit => $Param{Limit},
    );

    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Roles{ $Row[0] } = $Row[1];
    }

    return %Roles;
}

1;
