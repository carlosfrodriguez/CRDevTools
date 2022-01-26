# --
# Copyright (C) 2022 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Dev::SystemAddress;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::SystemAddress',
);

=head1 NAME

Dev::SystemAddress Address - Ticket System Address Dev lib

=head1 SYNOPSIS

All System Address Development functions.

=head1 PUBLIC INTERFACE

=head2 new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $ValidObject = $Kernel::OM->Get('Dev::System Address');

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

=head2 SystemAddressDelete()

Deletes a System Address from DB

    my $Success = $DevSystemAddressObject->SystemAddressDelete(
        SystemAddressID   => 123,                      # SystemAddressID or Name is required
        Name              => 'Some SystemAddress',
        Email             => 'Some@email',
    );

Returns:
    $Success = 1;                           # or false if there was any error.

=cut

sub SystemAddressDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{SystemAddress} && !$Param{SystemAddressID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need User or UserID!'
        );
        return;
    }

    # set SystemAddressID
    my $SystemAddressID = $Param{SystemAddressID} || '';
    if ( !$SystemAddressID ) {

        # TODO: Implement a lookup

        # my $SystemAddressID = $Kernel::OM->Get('Kernel::System::SystemAddress')->System AddressLookup(
        #     System Address => $Param{System Address},
        # );
    }
    if ( !$SystemAddressID ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'SystemAddress is invalid!'
        );
        return;
    }

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # # TODO: Remove auto-responses?
    # return if !$DBObject->Do(
    #     SQL => "
    #         DELETE FROM auto_response
    #         WHERE system_address_id = ?",
    #     Bind => [ \$SystemAddressID, ],
    # );

    # TODO: Remove queues?

    # Delete System Address from DB.
    return if !$DBObject->Do(
        SQL => "
            DELETE FROM system_address
            WHERE id = ?",
        Bind  => [ \$SystemAddressID ],
        Limit => 1,
    );

    # Delete cache.
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => 'SystemAddress',
    );
    return 1;
}

=head2 SystemAddressSearch()

To search system addresses

    my %List = $DevSystemAddressObject->SystemAddressSearch(
        Name  => '*some*', # also 'hans+huber' possible
        Email => '*some*', # also 'hans+huber' possible
        Valid => 1,        # not required
    );

=cut

sub SystemAddressSearch {
    my ( $Self, %Param ) = @_;

    my %SystemAddresses;
    my $Valid = defined $Param{Valid} ? $Param{Valid} : 1;

    if ( !$Param{Name} && !$Param{Email} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Name or Email!',
        );
        return;
    }

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # Get like escape string needed for some databases (e.g. oracle).
    my $LikeEscapeString = $DBObject->GetDatabaseFunction('LikeEscapeString');

    # Build SQL string 1/2.
    my $SQL = '
        SELECT id, value0, value1
        FROM system_address
        WHERE';

    # Build SQL string 2/2.
    if ( $Param{Name} ) {
        $Param{Name} =~ s/\*/%/g;
        $SQL .= ' value1 LIKE '
            . "'" . $DBObject->Quote( $Param{Name}, 'Like' ) . "'"
            . "$LikeEscapeString";
    }
    else {
        $Param{Email} =~ s/\*/%/g;
        $SQL .= ' value0 LIKE '
            . "'" . $DBObject->Quote( $Param{Email}, 'Like' ) . "'"
            . "$LikeEscapeString";
    }

    # Add valid option.
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
        $SystemAddresses{ $Row[0] } = $Row[1];
    }

    return %SystemAddresses;
}

1;
