# --
# Kernel/System/CR/Dev/State.pm - all Ticket State Development functions
# Copyright (C) 2001-2014 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::CR::Dev::State;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

=head1 NAME

Kernel::System::CR::Dev::State - Ticket State Dev lib

=head1 SYNOPSIS

All Ticket State Development functions.

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
    use Kernel::System::CR::Dev::State;

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
    my $DevStateObject = Kernel::System::CR::Dev::State->new(
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
        ConfigObject LogObject TimeObject DBObject MainObject EncodeObject StateObject
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

=item StateDelete()

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
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'Need User or UserID!'
        );
        return;
    }

    # set StateID
    my $StateID = $Param{StateID} || '';
    if ( !$StateID ) {
        my $StateID = $Self->{StateObject}->StateLookup(
            State => $Param{State},
        );
    }
    if ( !$StateID ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'State is invalid!'
        );
        return;
    }

    # delete State from DB
    return if !$Self->{DBObject}->Do(
        SQL => "
            DELETE FROM ticket_state
            WHERE id = ?",
        Bind  => [ \$StateID ],
        Limit => 1,
    );

    # delete cache
    $Self->{StateObject}->{CacheInternalObject}->CleanUp();

    return 1;
}

=item StateSearch()

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
        FROM ticket_state
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
        $States{ $Row[0] } = $Row[1];
    }

    return %States;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the CRDevTools project (L<https://github.com/carlosfrodriguez/CRDevTools/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut