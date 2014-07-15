# --
# Kernel/System/CR/Dev/Queue.pm - all Ticket Queue Development functions
# Copyright (C) 2001-2014 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::CR::Dev::Queue;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

=head1 NAME

Kernel::System::CR::Dev::Queue - Ticket Queue Dev lib

=head1 SYNOPSIS

All Ticket Queue Development functions.

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
    use Kernel::System::CR::Dev::Queue;

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
    my $DevQueueObject = Kernel::System::CR::Dev::Queue->new(
        ConfigObject       => $ConfigObject,
        LogObject          => $LogObject,
        DBObject           => $DBObject,
        MainObject         => $MainObject,
        TimeObject         => $TimeObject,
        EncodeObject       => $EncodeObject,
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
        ConfigObject LogObject TimeObject DBObject MainObject EncodeObject QueueObject
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
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'Need User or UserID!'
        );
        return;
    }

    # set QueueID
    my $QueueID = $Param{QueueID} || '';
    if ( !$QueueID ) {
        my $QueueID = $Self->{QueueObject}->QueueLookup(
            Queue => $Param{Queue},
        );
    }
    if ( !$QueueID ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'Queue is invalid!'
        );
        return;
    }

    # delete from queue autoresponses
    return if !$Self->{DBObject}->Do(
        SQL => "
            DELETE FROM queue_auto_response
            WHERE queue_id = ?",
        Bind => [ \$QueueID, ],
    );

    # delete from queue preferences
    return if !$Self->{DBObject}->Do(
        SQL => "
            DELETE FROM queue_preferences
            WHERE queue_id = ?",
        Bind => [ \$QueueID, ],
    );

    # delete from queue standard template
    return if !$Self->{DBObject}->Do(
        SQL => "
            DELETE FROM queue_standard_template
            WHERE queue_id = ?",
        Bind => [ \$QueueID, ],
    );

    # delete from personal queues
    return if !$Self->{DBObject}->Do(
        SQL => "
            DELETE FROM personal_queues
            WHERE queue_id = ?",
        Bind => [ \$QueueID, ],
    );

    # delete Queue from DB
    return if !$Self->{DBObject}->Do(
        SQL => "
            DELETE FROM queue
            WHERE id = ?",
        Bind  => [ \$QueueID ],
        Limit => 1,
    );

    # delete cache
    $Self->{QueueObject}->{CacheInternalObject}->CleanUp();

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
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'Need Name!',
        );
        return;
    }

    # get like escape string needed for some databases (e.g. oracle)
    my $LikeEscapeString = $Self->{DBObject}->GetDatabaseFunction('LikeEscapeString');

    # build SQL string 1/2
    my $SQL = '
        SELECT id, name
        FROM queue
        WHERE';

    # build SQL string 2/2
    $Param{Name} =~ s/\*/%/g;
    $SQL .= ' name LIKE '
        . "'" . $Self->{DBObject}->Quote( $Param{Name}, 'Like' ) . "'"
        . "$LikeEscapeString";

    # add valid option
    if ($Valid) {
        $SQL .= " AND valid_id IN (" . join( ', ', $Self->{ValidObject}->ValidIDsGet() ) . ")";
    }

    # get data
    return if !$Self->{DBObject}->Prepare(
        SQL   => $SQL,
        Limit => $Param{Limit},
    );

    # fetch the result
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $Queues{ $Row[0] } = $Row[1];
    }

    return %Queues;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the CRDevTools project (L<https://github.com/carlosfrodriguez/CRDevTools/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
