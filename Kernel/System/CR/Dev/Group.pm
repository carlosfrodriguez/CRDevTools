# --
# Kernel/System/CR/Dev/Group.pm - all Ticket Group Development functions
# Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::CR::Dev::Group;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::DB',
    'Kernel::System::Group',
    'Kernel::System::log',
);

=head1 NAME

Kernel::System::CR::Dev::Group - Ticket Group Dev lib

=head1 SYNOPSIS

All Ticket Group Development functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $ValidObject = $Kernel::OM->Get('Kernel::System::CR::Dev::Group');

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

=item GroupDelete()

Deletes a ticket Group from DB

    my $Success = $DevGroupObject->GroupDelete(
        GroupID => 123,                      # GroupID or Group is required
        Group   => 'Some Group',
    );

Returns:
    $Sucesss = 1;                           # or false if there was any error.

=cut

sub GroupDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Group} && !$Param{GroupID} ) {
        $Kernel::OM->Get('Kernel::System::log')->Log(
            Group   => 'error',
            Message => 'Need User or UserID!'
        );
        return;
    }

    # get group object
    my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');

    # set GroupID
    my $GroupID = $Param{GroupID} || '';
    if ( !$GroupID ) {
        my $GroupID = $GroupObject->GroupLookup(
            Group => $Param{Group},
        );
    }
    if ( !$GroupID ) {
        $Kernel::OM->Get('Kernel::System::log')->Log(
            Group   => 'error',
            Message => 'Group is invalid!'
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # delete Group User relations
    return if !$DBObject->Do(
        SQL => "
            DELETE FROM group_user
            WHERE group_id = ?",
        Bind  => [ \$GroupID ],
        Limit => 1,
    );

    # delete Group Role relations
    return if !$DBObject->Do(
        SQL => "
            DELETE FROM group_role
            WHERE group_id = ?",
        Bind  => [ \$GroupID ],
        Limit => 1,
    );

    # delete Group from DB
    return if !$DBObject->Do(
        SQL => "
            DELETE FROM groups
            WHERE id = ?",
        Bind  => [ \$GroupID ],
        Limit => 1,
    );

    # delete cache
    $GroupObject->{CacheInternalObject}->CleanUp();

    return 1;
}

=item GroupSearch()

To search Groups

    my %List = $DevGroupObject->GroupSearch(
        Name  => '*some*', # also 'hans+huber' possible
        Valid => 1,        # not required
    );

=cut

sub GroupSearch {
    my ( $Self, %Param ) = @_;

    my %Groups;
    my $Valid = defined $Param{Valid} ? $Param{Valid} : 1;

    # check needed stuff
    if ( !$Param{Name} ) {
        $Kernel::OM->Get('Kernel::System::log')->Log(
            Group   => 'error',
            Message => 'Need Name!',
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
        FROM groups
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
        $Groups{ $Row[0] } = $Row[1];
    }

    return %Groups;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the CRDevTools project (L<https://github.com/carlosfrodriguez/CRDevTools/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
