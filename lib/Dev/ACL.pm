# --
# Copyright (C) 2022 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Dev::ACL;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::Valid'
);

=head1 NAME

Dev::ACL - Ticket ACL Dev lib

=head1 SYNOPSIS

All Ticket ACL Development functions.

=head1 PUBLIC INTERFACE

=head2 new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $ValidObject = $Kernel::OM->Get('Dev::ACL');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # 0=off; 1=on;
    $Self->{Debug} = $Param{Debug} || 0;

    return $Self;
}

=head2 ACLSearch()

To search ACLs

    my %List = $DevACLObject->ACLSearch(
        Name  => '*some*', # also 'hans+huber' possible
        Valid => 1,        # not required
    );

=cut

sub ACLSearch {
    my ( $Self, %Param ) = @_;

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
        FROM acl
        WHERE';

    # build SQL string 2/2
    $Param{Name} =~ s/\*/%/g;
    $SQL .= ' name LIKE '
        . "'" . $DBObject->Quote( $Param{Name}, 'Like' ) . "'"
        . "$LikeEscapeString";

    # add valid option
    if ($Valid) {
        $SQL .= " AND valid_id IN (" . join( ', ', $Kernel::OM->Get('Kernel::System::Valid')->ValidIDsGet() ) . ")";
    }

    # get data
    return if !$DBObject->Prepare(
        SQL => $SQL,
    );

    my %ACLs;

    # fetch the result
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ACLs{ $Row[0] } = $Row[1];
    }

    return %ACLs;
}

1;
