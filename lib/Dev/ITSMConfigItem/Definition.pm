# --
# Copyright (C) 2022 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Dev::ITSMConfigItem::Definition;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::GeneralCatalog',
    'Kernel::System::Log',
    'Kernel::System::Queue',
);

=head1 NAME

Dev::ITSMConfigItem::Definition - ITSMConfigItem Definition Dev lib

=head1 SYNOPSIS

All ITSMConfigItem Definition Development functions.

=head1 PUBLIC INTERFACE

=head2 new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $ITSMConfigItemDefinitionObject = $Kernel::OM->Get('Dev::ITSMConfigItemDefinition');

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

=head2 DefinitionDelete()

Deletes a ITSMConfigItemDefinition from DB

    my $Success = $DevITSMConfigItemDefinitionObject->DefinitionDelete(
        DefinitionID => 123,
    );

Returns:
    $Success = 1;                           # or false if there was any error.

=cut

sub DefinitionDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{DefinitionID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need DefinitionID!'
        );
        return;
    }

    # set ITSMConfigItemDefinitionID
    my $ITSMConfigItemDefinitionID = $Param{DefinitionID} || '';

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # delete ITSMConfigItemDefinition
    return if !$DBObject->Do(
        SQL => "
            DELETE FROM configitem_definition
            WHERE id = ?",
        Bind => [ \$ITSMConfigItemDefinitionID, ],
    );

    return 1;
}

=head2 DefinitionSearch()

To search ITSMConfigItem Definitions

    my %List = $DevITSMConfigItemDefinitionObject->DefinitionSearch(
        Class  => '*some*', # also 'hans+huber' possible
    );

=cut

sub DefinitionSearch {
    my ( $Self, %Param ) = @_;

    my %Definitions;

    # check needed stuff
    if ( !$Param{Class} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Name!',
        );
        return;
    }

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # get like escape string needed for some databases (e.g. oracle)
    my $LikeEscapeString = $DBObject->GetDatabaseFunction('LikeEscapeString');

    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    my $ClassList            = $GeneralCatalogObject->ItemList(
        Class => 'ITSM::ConfigItem::Class',
    );
    my %ClassLookup = reverse %{$ClassList};

    # get data
    return if !$DBObject->Prepare(
        SQL => '
        SELECT id, class_id
        FROM ITSMConfigItemDefinition
        WHERE class_id = ?',
        Bind  => [ \$ClassLookup{ $Param{Class} } ],
        Limit => $Param{Limit},
    );

    # fetch the result
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Definitions{ $Row[0] } = $ClassList->{ $Row[1] };
    }

    return %Definitions;
}

1;
