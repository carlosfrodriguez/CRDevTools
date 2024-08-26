# --
# Copyright (C) 2022 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Dev::GeneralCatalog;

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

Dev::GeneralCatalog - Ticket GeneralCatalog Dev lib

=head1 SYNOPSIS

All Ticket GeneralCatalog Development functions.

=head1 PUBLIC INTERFACE

=head2 new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $GeneralCatalogObject = $Kernel::OM->Get('Dev::GeneralCatalog');

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

=head2 GeneralCatalogDelete()

Deletes a ticket GeneralCatalog from DB

    my $Success = $DevGeneralCatalogObject->GeneralCatalogDelete(
        GeneralCatalogID => 123,                      # GeneralCatalogID or Name is required
        Name             => 'Some Queue',
    );

Returns:
    $Success = 1;                           # or false if there was any error.

=cut

sub GeneralCatalogDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Name} && !$Param{GeneralCatalogID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Name or GeneralCatalogID!'
        );
        return;
    }

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # set GeneralCatalogID
    my $GeneralCatalogID = $Param{GeneralCatalogID} || '';
    if ( !$GeneralCatalogID ) {

        return if !$DBObject->Prepare(
            SQL => '
                SELECT id
                FROM general_catalog WHERE name = ?',
            Bind  => [ \$Param{Name} ],
            Limit => 1,
        );

        while ( my @Row = $DBObject->FetchrowArray() ) {
            $GeneralCatalogID = $Row[0];
        }
    }
    if ( !$GeneralCatalogID ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'GeneralCatalog is invalid!'
        );
        return;
    }

    # delete from GeneralCatalog Preferences
    return if !$DBObject->Do(
        SQL => "
            DELETE FROM general_catalog_preferences
            WHERE general_catalog_id = ?",
        Bind => [ \$GeneralCatalogID, ],
    );

    # delete GeneralCatalog from DB
    return if !$DBObject->Do(
        SQL => "
            DELETE FROM general_catalog
            WHERE id = ?",
        Bind  => [ \$GeneralCatalogID ],
        Limit => 1,
    );

    # delete cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => 'GeneralCatalog',
    );
    return 1;
}

=head2 GeneralCatalogSearch()

To search GeneralCatalogs

    my %List = $DevGeneralCatalogObject->GeneralCatalogSearch(
        Name  => '*some*', # also 'hans+huber' possible
        Valid => 1,        # not required
    );

=cut

sub GeneralCatalogSearch {
    my ( $Self, %Param ) = @_;

    my %GeneralCatalogs;
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
        FROM general_catalog
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
        $GeneralCatalogs{ $Row[0] } = $Row[1];
    }

    return %GeneralCatalogs;
}

1;
