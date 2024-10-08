# --
# Copyright (C) 2022 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Dev::User;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::User',
);

=head1 NAME

Dev::User - User Dev lib

=head1 SYNOPSIS

All User Development functions.

=head1 PUBLIC INTERFACE

=head2 new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $ValidObject = $Kernel::OM->Get('Dev::User');

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

=head2 UserDelete()

Deletes a user from DB, removes any preference group and role relation.
If user is used in any other table, user will not be deleted

    my $Success = $DevUserObject->UserDelete(
        UserID => 123,                      # UserID or User is required
        User   => 'Some user login',
    );

Returns:
    $Sucesss = 1;                           # or false if there was any error.

=cut

sub UserDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{User} && !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need User or UserID!'
        );
        return;
    }

    # set UserID
    my $UserID = $Param{UserID} || '';
    if ( !$UserID ) {
        my $UserID = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
            User => $Param{User},
        );
    }
    if ( !$UserID ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'User is invalid!'
        );
        return;
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # preferences table data
    my $PreferencesTable       = $ConfigObject->Get('PreferencesTable')       || 'user_preferences';
    my $PreferencesTableUserID = $ConfigObject->Get('PreferencesTableUserID') || 'user_id';

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # delete from preferences
    return if !$DBObject->Do(
        SQL => "
            DELETE FROM $PreferencesTable
            WHERE $PreferencesTableUserID = ?",
        Bind => [ \$Param{UserID}, ],
    );

    # delete existing group user relation
    return if !$DBObject->Do(
        SQL => '
            DELETE FROM group_user
            WHERE user_id = ?',
        Bind => [ \$Param{UserID}, ],
    );

    # delete existing role user relation
    return if !$DBObject->Do(
        SQL => '
            DELETE FROM role_user
            WHERE user_id = ?',
        Bind => [ \$Param{UserID}, ],
    );

    # delete existing article_flag user relation
    return if !$DBObject->Do(
        SQL => '
            DELETE FROM article_flag
            WHERE create_by = ?',
        Bind => [ \$Param{UserID}, ],
    );

    # delete existing ticket_history user relation
    return if !$DBObject->Do(
        SQL => '
            DELETE FROM ticket_history
            WHERE owner_id = ?
            OR create_by = ?',
        Bind => [ \$Param{UserID}, \$Param{UserID} ],
    );

    # delete existing link_relation user relation
    return if !$DBObject->Do(
        SQL => '
            DELETE FROM link_relation
            WHERE create_by = ?',
        Bind => [ \$Param{UserID}, ],
    );

    my $Version = $ConfigObject->Get('Version');
    my ($MajorVersion) = $Version =~ m{\A(\d+)\.}msx;

    # Delete user configuration
    if ( $MajorVersion >= 8 ) {
        return if !$DBObject->Do(
            SQL => '
            DELETE FROM user_config
            WHERE user_id = ?',
            Bind => [ \$Param{UserID}, ],
        );
    }

    # get user table
    my $UserTable       = $ConfigObject->Get('DatabaseUserTable')       || 'user';
    my $UserTableUserID = $ConfigObject->Get('DatabaseUserTableUserID') || 'id';
    my $UserTableUser   = $ConfigObject->Get('DatabaseUserTableUser')   || 'login';

    # delete user from DB
    return if !$DBObject->Do(
        SQL => "
            DELETE FROM $UserTable
            WHERE $UserTableUserID = ?",
        Bind  => [ \$UserID ],
        Limit => 1,
    );

    # delete cache
    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');
    $CacheObject->CleanUp(
        Type => 'User',
    );
    $CacheObject->CleanUp(
        Type => 'Group',
    );

    return 1;
}

sub RelatedTicketsGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{User} && !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need User or UserID!'
        );
        return;
    }

    # set UserID
    my $UserID = $Param{UserID} || '';
    if ( !$UserID ) {
        my $UserID = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
            User => $Param{User},
        );
    }
    if ( !$UserID ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'User is invalid!'
        );
        return;
    }

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # build SQL string
    my $SQL = '
        SELECT id, tn
        FROM ticket
        WHERE create_by = ?
            OR change_by = ?
            OR responsible_user_id = ?
            OR user_id = ?';

    # get data
    return if !$DBObject->Prepare(
        SQL   => $SQL,
        Bind  => [ \$UserID, \$UserID, \$UserID, \$UserID, ],
        Limit => $Param{Limit},
    );

    my %TicketIDs;

    # fetch the result
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $TicketIDs{ $Row[0] } = $Row[1];
    }

    # build SQL string
    $SQL = '
        SELECT ticket_id, id
        FROM article
        WHERE create_by = ?
            OR change_by = ?';

    # get data
    return if !$DBObject->Prepare(
        SQL   => $SQL,
        Bind  => [ \$UserID, \$UserID, ],
        Limit => $Param{Limit},
    );

    # fetch the result
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $TicketIDs{ $Row[0] } = $Row[1];
    }

    return keys %TicketIDs;
}

1;
