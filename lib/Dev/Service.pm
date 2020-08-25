# --
# Copyright (C) 2020 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Dev::Service;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::Queue',
);

=head1 NAME

Dev::Service - Ticket Service Dev lib

=head1 SYNOPSIS

All Ticket Service Development functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $ServiceObject = $Kernel::OM->Get('Dev::Service');

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

=item ServiceDelete()

Deletes a ticket Service from DB

    my $Success = $DevServiceObject->ServiceDelete(
        ServiceID => 123,                      # ServiceID or Service is required
        Service   => 'Some Queue',
    );

Returns:
    $Success = 1;                           # or false if there was any error.

=cut

sub ServiceDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Service} && !$Param{ServiceID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Service or ServiceID!'
        );
        return;
    }

    # set ServiceID
    my $ServiceID = $Param{ServiceID} || '';
    if ( !$ServiceID ) {
        my $ServiceD = $Kernel::OM->Get('Kernel::System::Queue')->QueueLookup(
            Name => $Param{Service},
        );
    }
    if ( !$ServiceID ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Service is invalid!'
        );
        return;
    }

    # get DB object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # delete from service customer user
    return if !$DBObject->Do(
        SQL => "
            DELETE FROM service_customer_user
            WHERE service_id = ?",
        Bind => [ \$ServiceID, ],
    );

    # delete from service preferences
    return if !$DBObject->Do(
        SQL => "
            DELETE FROM service_preferences
            WHERE service_id = ?",
        Bind => [ \$ServiceID, ],
    );

    # delete from service sla
    return if !$DBObject->Do(
        SQL => "
            DELETE FROM service_sla
            WHERE service_id = ?",
        Bind => [ \$ServiceID, ],
    );

    # delete from personal services
    return if !$DBObject->Do(
        SQL => "
            DELETE FROM personal_services
            WHERE service_id = ?",
        Bind => [ \$ServiceID, ],
    );

    # delete Service from DB
    return if !$DBObject->Do(
        SQL => "
            DELETE FROM service
            WHERE id = ?",
        Bind  => [ \$ServiceID ],
        Limit => 1,
    );

    # delete cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => 'Service',
    );
    return 1;
}

=item ServiceSearch()

To search Queues

    my %List = $DevServiceObject->ServiceSearch(
        Name  => '*some*', # also 'hans+huber' possible
        Valid => 1,        # not required
    );

=cut

sub ServiceSearch {
    my ( $Self, %Param ) = @_;

    my %Services;
    my $Valid = defined $Param{Valid} ? $Param{Valid} : 1;

    # check needed stuff
    if ( !$Param{Name} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Name!',
        );
        return;
    }

    # get DB object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # get like escape string needed for some databases (e.g. oracle)
    my $LikeEscapeString = $DBObject->GetDatabaseFunction('LikeEscapeString');

    # build SQL string 1/2
    my $SQL = '
        SELECT id, name
        FROM service
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
        $Services{ $Row[0] } = $Row[1];
    }

    return %Services;
}

1;

=back
