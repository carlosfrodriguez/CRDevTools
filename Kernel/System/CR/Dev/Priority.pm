# --
# Copyright (C) 2017 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::CR::Dev::Priority;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::Priority',
);

=head1 NAME

Kernel::System::CR::Dev::Priority - Ticket Priority Dev lib

=head1 SYNOPSIS

All Ticket Priority Development functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $ValidObject = $Kernel::OM->Get('Kernel::System::CR::Dev::Priority');

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

=item PriorityDelete()

Deletes a ticket Priority from DB

    my $Success = $DevPriorityObject->PriorityDelete(
        PriorityID => 123,                      # PriorityID or Priority is required
        Priority   => 'Some Priority',
    );

Returns:
    $Success = 1;                           # or false if there was any error.

=cut

sub PriorityDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Priority} && !$Param{PriorityID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need User or UserID!'
        );

        return;
    }

    # set PriorityID
    my $PriorityID = $Param{PriorityID} || '';
    if ( !$PriorityID ) {
        my $PriorityID = $$Kernel::OM->Get('Kernel::System::Priority')->PriorityLookup(
            Priority => $Param{Priority},
        );
    }
    if ( !$PriorityID ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Priority is invalid!'
        );

        return;
    }

    # delete Priority from DB
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => "
            DELETE FROM ticket_Priority
            WHERE id = ?",
        Bind  => [ \$PriorityID ],
        Limit => 1,
    );

    # delete cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => 'Priority',
    );

    return 1;
}

=item PrioritySearch()

To search Priorities

    my %List = $DevPriorityObject->PrioritySearch(
        Name  => '*some*', # also 'hans+huber' possible
        Valid => 1,        # not required
    );

=cut

sub PrioritySearch {
    my ( $Self, %Param ) = @_;

    my %Prioritys;
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
        FROM ticket_priority
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
        $Prioritys{ $Row[0] } = $Row[1];
    }

    return %Prioritys;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is is a component of the CRDevTools project (L<https://github.com/carlosfrodriguez/CRDevTools/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
