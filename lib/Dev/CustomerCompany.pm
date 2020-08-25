# --
# Copyright (C) 2017 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Dev::CustomerCompany;

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

Dev::CustomerCompany - CustomerCompany Dev lib

=head1 SYNOPSIS

All CustomerCompany Development functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $DevCustomerCompanyObject = $Kernel::OM->Get('Dev::CustomerCompany');

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

=item CustomerCompanyDelete()

Deletes a CustomerCompany from DB.
If CustomerCompany is used in any other table, CustomerCompany will not be deleted

    my $Success = $DevCustomerCompanyObject->CustomerCompanyDelete(
        CustomerID => 'Some Customer ID',
    );

Returns:
    $Sucesss = 1;                           # or false if there was any error.

=cut

sub CustomerCompanyDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{CustomerID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need CustomerID'
        );
        return;
    }

    my $CustomerID = $Param{CustomerID};

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my $Config = $ConfigObject->Get('CustomerPreferences') // {};

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # get CustomerCompany table
    my $CustomerCompanyTable = $ConfigObject->Get('CustomerCompany')->{Table} || 'customer_company';
    my $CustomerCompanyTableCustomerKey = $ConfigObject->Get('CustomerCompany')->{CustomerCompanyKey} || 'customer_id';

    # delete CustomerCompany from DB
    return if !$DBObject->Do(
        SQL => "
            DELETE FROM $CustomerCompanyTable
            WHERE $CustomerCompanyTableCustomerKey = ?",
        Bind  => [ \$CustomerID ],
        Limit => 1,
    );

    # delete cache
    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');
    $CacheObject->CleanUp(
        Type => 'CustomerCompany',
    );

    for my $Backend ( 1 .. 10 ) {
        $CacheObject->CleanUp(
            Type => 'CustomerCompany' . $Backend . '_CustomerCompanyList',
        );
        $CacheObject->CleanUp(
            Type => 'CustomerCompany' . $Backend . '_CustomerCompanySearchDetail',
        );
        $CacheObject->CleanUp(
            Type => 'CustomerCompany' . $Backend . '_CustomerSearchDetailDynamicFields',
        );
    }

    return 1;
}

1;

=back
