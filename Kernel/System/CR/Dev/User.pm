# --
# Kernel/System/CRDevDelete.pm - all Development Delete functions
# Copyright (C) 2001-2014 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::CRDevDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

=head1 NAME

Kernel::System::DevDelete - Dev Delete lib

=head1 SYNOPSIS

All Development Delete functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::Config;
    use Kernel::System::Encode;
    use Kernel::System::Log;
    use Kernel::System::Time;
    use Kernel::System::Main;
    use Kernel::System::DB;
    use Kernel::System::CRDevDelete;

    my $ConfigObject = Kernel::Config->new();
    my $EncodeObject = Kernel::System::Encode->new(
        ConfigObject => $ConfigObject,
    );
    my $LogObject = Kernel::System::Log->new(
        ConfigObject => $ConfigObject,
        EncodeObject => $EncodeObject,
    );
    my $TimeObject = Kernel::System::Time->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
    );
    my $MainObject = Kernel::System::Main->new(
        ConfigObject => $ConfigObject,
        EncodeObject => $EncodeObject,
        LogObject    => $LogObject,
    );
    my $DBObject = Kernel::System::DB->new(
        ConfigObject => $ConfigObject,
        EncodeObject => $EncodeObject,
        LogObject    => $LogObject,
        MainObject   => $MainObject,
    );
    my $CRDevDeleteObject = Kernel::System::CRDevDelete->new(
        ConfigObject       => $ConfigObject,
        LogObject          => $LogObject,
        DBObject           => $DBObject,
        MainObject         => $MainObject,
        TimeObject         => $TimeObject,
        EncodeObject       => $EncodeObject,
        GroupObject        => $GroupObject,        # if given
        CustomerUserObject => $CustomerUserObject, # if given
        QueueObject        => $QueueObject,        # if given
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # 0=off; 1=on;
    $Self->{Debug} = $Param{Debug} || 0;

    # get needed objects
    for my $Needed (
        qw(
        ConfigObject LogObject TimeObject DBObject MainObject EncodeObject UserObject
        GroupObject
        )
        )
    {
        if ( $Param{$Needed} ) {
            $Self->{$Needed} = $Param{$Needed};
        }
        else {
            die "Got no $Needed!";
        }
    }

    # set lower if database is case sensitive
    $Self->{Lower} = '';
    if ( $Self->{DBObject}->GetDatabaseFunction('CaseSensitive') ) {
        $Self->{Lower} = 'LOWER';
    }

    return $Self;
}

=item UserDelete()

Deletes a user from DB removes any preference group and role relation.
If user is used in any other table, user will not be deletes

    my $Success = $DevDeleteObject->UserDelete(
        UserID => 123,                      # UserID or User is requiered
        User   => 'Some user login',
    );

Returns:
    $Sucesss = 1;                           # or false if there was any error.

=cut

sub UserDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{User} && !$Param{UserID} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'Need User or UserID!'
        );
        return;
    }

    # set UserID
    my $UserID = $Param{UserID} || '';
    if ( !$UserID ) {
        my $UserID = $Self->{UserObject}->UserLookup(
            User => $Param{User},
        );
    }
    if ( !$UserID ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'User is invalid!'
        );
        return;
    }

    # preferences table data
    my $PreferencesTable = $Self->{ConfigObject}->Get('PreferencesTable') || 'user_preferences';
    my $PreferencesTableUserID = $Self->{ConfigObject}->Get('PreferencesTableUserID') || 'user_id';

    # delete from preferences
    return if !$Self->{DBObject}->Do(
        SQL => "
            DELETE FROM $PreferencesTable
            WHERE $PreferencesTableUserID = ?",
        Bind => [ \$Param{UserID}, ],
    );

    # delete existing group user relation
    return if !$Self->{DBObject}->Do(
        SQL => '
            DELETE FROM group_user
            WHERE user_id = ?',
        Bind => [ \$Param{UserID}, ],
    );

    # delete existing role user relation
    return if !$Self->{DBObject}->Do(
        SQL => '
            DELETE FROM role_user
            WHERE user_id = ?',
        Bind => [ \$Param{UserID}, ],
    );

    # get user table
    my $UserTable       = $Self->{ConfigObject}->Get('DatabaseUserTable')       || 'user';
    my $UserTableUserID = $Self->{ConfigObject}->Get('DatabaseUserTableUserID') || 'id';
    my $UserTableUser   = $Self->{ConfigObject}->Get('DatabaseUserTableUser')   || 'login';

    # delete user from DB
    return if !$Self->{DBObject}->Do(
        SQL => "
            DELETE FROM $UserTable
            WHERE $UserTableUserID = ?",
        Bind  => [ \$UserID ],
        Limit => 1,
    );

    # delete cache
    $Self->{UserObject}->{CacheInternalObject}->CleanUp();
    $Self->{GroupObject}->{CacheInternalObject}->CleanUp();

    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the CRDevTools project (L<https://github.com/carlosfrodriguez/CRDevTools/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
