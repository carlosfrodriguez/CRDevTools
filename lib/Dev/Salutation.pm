# --
# Copyright (C) 2022 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Dev::Salutation;

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

Dev::Salutation - Salutation Dev lib

=head1 SYNOPSIS

All Salutation Development functions.

=head1 PUBLIC INTERFACE

=head2 new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $SalutationObject = $Kernel::OM->Get('Dev::Salutation');

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

=head2 SalutationDelete()

Deletes a Salutation from DB

    my $Success = $DevSalutationObject->SalutationDelete(
        SalutationID => 123,                      # SalutationID or Salutation is required
        Salutation   => 'Some Salutation',
    );

Returns:
    $Success = 1;                           # or false if there was any error.

=cut

sub SalutationDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Salutation} && !$Param{SalutationID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Salutation or SalutationID!'
        );
        return;
    }

    # set SalutationID
    my $SalutationID = $Param{SalutationID} || '';

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Prepare(
        SQL => '
            SELECT id
            FROM salutation WHERE name = ?',
        Bind  => [ \$Param{Salutation} ],
        Limit => 1,
    );

    while ( my @Row = $DBObject->FetchrowArray() ) {
        $SalutationID = $Row[0];
    }

    if ( !$SalutationID ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Salutation is invalid!'
        );
        return;
    }

    # delete salutation
    return if !$DBObject->Do(
        SQL => "
            DELETE FROM salutation
            WHERE id = ?",
        Bind => [ \$SalutationID, ],
    );

    # delete cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => 'Salutation',
    );
    return 1;
}

=head2 SalutationSearch()

To search Salutations

    my %List = $DevSalutationObject->SalutationSearch(
        Name  => '*some*', # also 'hans+huber' possible
        Valid => 1,        # not required
    );

=cut

sub SalutationSearch {
    my ( $Self, %Param ) = @_;

    my %Salutations;
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
        FROM salutation
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
        $Salutations{ $Row[0] } = $Row[1];
    }

    return %Salutations;
}

1;
