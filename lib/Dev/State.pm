# --
# Copyright (C) 2022 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Dev::State;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::State',
);

=head1 NAME

Dev::State - Ticket State Dev lib

=head1 SYNOPSIS

All Ticket State Development functions.

=head1 PUBLIC INTERFACE

=head2 new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $ValidObject = $Kernel::OM->Get('Dev::State');

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

=head2 StateDelete()

Deletes a ticket State from DB

    my $Success = $DevStateObject->StateDelete(
        StateID => 123,                      # StateID or State is requiered
        State   => 'Some State',
    );

Returns:
    $Sucesss = 1;                           # or false if there was any error.

=cut

sub StateDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{State} && !$Param{StateID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need User or UserID!'
        );
        return;
    }

    # set StateID
    my $StateID = $Param{StateID} || '';
    if ( !$StateID ) {
        my $StateID = $Kernel::OM->Get('Kernel::System::State')->StateLookup(
            State => $Param{State},
        );
    }
    if ( !$StateID ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'State is invalid!'
        );
        return;
    }

    # delete State from DB
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => "
            DELETE FROM ticket_state
            WHERE id = ?",
        Bind  => [ \$StateID ],
        Limit => 1,
    );

    # delete cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => 'State',
    );
    return 1;
}

=head2 StateSearch()

To search States

    my %List = $DevStateObject->StateSearch(
        Name  => '*some*', # also 'hans+huber' possible
        Valid => 1,        # not required
    );

=cut

sub StateSearch {
    my ( $Self, %Param ) = @_;

    my %States;
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
        FROM ticket_state
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
        $States{ $Row[0] } = $Row[1];
    }

    return %States;
}

1;
