# --
# Copyright (C) 2020 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Dev::CustomerUser;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::Log',
);

=head1 NAME

Dev::CustomerUser - CustomerUser Dev lib

=head1 SYNOPSIS

All CustomerUser Development functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $DevCustomerUserObject = $Kernel::OM->Get('Dev::CustomerUser');

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

=item CustomerUserDelete()

Deletes a Customeruser from DB, removes any preference group and role relation.
If Customeruser is used in any other table, Customeruser will not be deleted

    my $Success = $DevCustomerUserObject->CustomerUserDelete(
        CustomerUser => 'Some Customeruser login',
    );

Returns:
    $Sucesss = 1;                           # or false if there was any error.

=cut

sub CustomerUserDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{CustomerUser} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need CustomerUser'
        );
        return;
    }

    my $CustomerUser = $Param{CustomerUser};

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my $Config = $ConfigObject->Get('CustomerPreferences') // {};

    # preferences table data
    my $PreferencesTable       = $Config->{Table}       || 'customer_preferences';
    my $PreferencesTableUserID = $Config->{TableUserID} || 'user_id';

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # delete from preferences
    return if !$DBObject->Do(
        SQL => "
            DELETE FROM $PreferencesTable
            WHERE $PreferencesTableUserID = ?",
        Bind => [ \$CustomerUser, ],
    );

    # delete existing group CustomerUser relation
    return if !$DBObject->Do(
        SQL => '
            DELETE FROM group_customer_user
            WHERE user_id = ?',
        Bind => [ \$CustomerUser, ],
    );

    # get CustomerUser table
    my $CustomerUserTable            = $ConfigObject->Get('CustomerUser')->{Table}       || 'customer_user';
    my $CustomerUserTableCustomerKey = $ConfigObject->Get('CustomerUser')->{CustomerKey} || 'login';

    # delete CustomerUser from DB
    return if !$DBObject->Do(
        SQL => "
            DELETE FROM $CustomerUserTable
            WHERE $CustomerUserTableCustomerKey = ?",
        Bind  => [ \$CustomerUser ],
        Limit => 1,
    );

    # delete cache
    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');
    $CacheObject->CleanUp(
        Type => 'CustomerUser',
    );
    $CacheObject->CleanUp(
        Type => 'CustomerGroup',
    );

    $CacheObject->CleanUp(
        Type => 'CustomerUser_CustomerSearch',
    );
    for my $Backend ( 1 .. 10 ) {
        $CacheObject->CleanUp(
            Type => 'CustomerUser' . $Backend . '_CustomerSearch',
        );
    }

    return 1;
}

1;

=back
