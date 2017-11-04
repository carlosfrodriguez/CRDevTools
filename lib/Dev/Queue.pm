# --
# Copyright (C) 2017 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Dev::Queue;

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

Dev::Queue - Ticket Queue Dev lib

=head1 SYNOPSIS

All Ticket Queue Development functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $ValidObject = $Kernel::OM->Get('Dev::Queue');

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

=item QueueDelete()

Deletes a ticket Queue from DB

    my $Success = $DevQueueObject->QueueDelete(
        QueueID => 123,                      # QueueID or Queue is requiered
        Queue   => 'Some Queue',
    );

Returns:
    $Sucesss = 1;                           # or false if there was any error.

=cut

sub QueueDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Queue} && !$Param{QueueID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need User or UserID!'
        );
        return;
    }

    # set QueueID
    my $QueueID = $Param{QueueID} || '';
    if ( !$QueueID ) {
        my $QueueID = $Kernel::OM->Get('Kernel::System::Queue')->QueueLookup(
            Queue => $Param{Queue},
        );
    }
    if ( !$QueueID ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Queue is invalid!'
        );
        return;
    }

    # get DB object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # delete from queue autoresponses
    return if !$DBObject->Do(
        SQL => "
            DELETE FROM queue_auto_response
            WHERE queue_id = ?",
        Bind => [ \$QueueID, ],
    );

    # delete from queue preferences
    return if !$DBObject->Do(
        SQL => "
            DELETE FROM queue_preferences
            WHERE queue_id = ?",
        Bind => [ \$QueueID, ],
    );

    # delete from queue standard template
    return if !$DBObject->Do(
        SQL => "
            DELETE FROM queue_standard_template
            WHERE queue_id = ?",
        Bind => [ \$QueueID, ],
    );

    # delete from personal queues
    return if !$DBObject->Do(
        SQL => "
            DELETE FROM personal_queues
            WHERE queue_id = ?",
        Bind => [ \$QueueID, ],
    );

    # delete Queue from DB
    return if !$DBObject->Do(
        SQL => "
            DELETE FROM queue
            WHERE id = ?",
        Bind  => [ \$QueueID ],
        Limit => 1,
    );

    # delete cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => 'Queue',
    );
    return 1;
}

=item QueueSearch()

To search Queues

    my %List = $DevQueueObject->QueueSearch(
        Name  => '*some*', # also 'hans+huber' possible
        Valid => 1,        # not required
    );

=cut

sub QueueSearch {
    my ( $Self, %Param ) = @_;

    my %Queues;
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
        FROM queue
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
        $Queues{ $Row[0] } = $Row[1];
    }

    return %Queues;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is is a component of the CRDevTools project (L<https://github.com/carlosfrodriguez/CRDevTools/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
