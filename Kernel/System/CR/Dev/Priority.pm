# --
# Kernel/System/CR/Dev/Priority.pm - all Ticket Priority Development functions
# Copyright (C) 2001-2014 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::CR::Dev::Priority;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

=head1 NAME

Kernel::System::CR::Dev::Priority - Ticket Priority Dev lib

=head1 SYNOPSIS

All Ticket Priority Development functions.

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
    use Kernel::System::CR::Dev::Priority;

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
    my $DevPriorityObject = Kernel::System::CR::Dev::Priority->new(
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
        ConfigObject LogObject TimeObject DBObject MainObject EncodeObject PriorityObject
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

=item PriorityDelete()

Deletes a ticket Priority from DB

    my $Success = $DevPriorityObject->PriorityDelete(
        PriorityID => 123,                      # PriorityID or Priority is requiered
        Priority   => 'Some Priority',
    );

Returns:
    $Sucesss = 1;                           # or false if there was any error.

=cut

sub PriorityDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Priority} && !$Param{PriorityID} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'Need User or UserID!'
        );
        return;
    }

    # set PriorityID
    my $PriorityID = $Param{PriorityID} || '';
    if ( !$PriorityID ) {
        my $PriorityID = $Self->{PriorityObject}->PriorityLookup(
            Priority => $Param{Priority},
        );
    }
    if ( !$PriorityID ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'Priority is invalid!'
        );
        return;
    }

    # delete Priority from DB
    return if !$Self->{DBObject}->Do(
        SQL => "
            DELETE FROM ticket_Priority
            WHERE id = ?",
        Bind  => [ \$PriorityID ],
        Limit => 1,
    );

    # delete cache
    $Self->{PriorityObject}->{CacheInternalObject}->CleanUp();

    return 1;
}

=item PrioritySearch()

To search Prioritys

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
        FROM ticket_Priority
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
        $Prioritys{ $Row[0] } = $Row[1];
    }

    return %Prioritys;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the CRDevTools project (L<https://github.com/carlosfrodriguez/CRDevTools/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
