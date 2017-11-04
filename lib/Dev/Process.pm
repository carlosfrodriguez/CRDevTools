# --
# Copyright (C) 2017 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Dev::Process;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DB',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
    'Kernel::System::Log',
    'Kernel::System::ProcessManagement::DB::Activity',
    'Kernel::System::ProcessManagement::DB::ActivityDialog',
    'Kernel::System::ProcessManagement::DB::Entity',
    'Kernel::System::ProcessManagement::DB::Process',
    'Kernel::System::ProcessManagement::DB::Transition',
    'Kernel::System::ProcessManagement::DB::TransitionAction',
    'Kernel::System::ProcessManagement::Process',
    'Kernel::System::Ticket',
    'Kernel::System::YAML',
);

=head1 NAME

Dev::Process - Process Dev lib

=head1 SYNOPSIS

All Process Development functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $ValidObject = $Kernel::OM->Get('Dev::Process');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub ProcessRemoveAll {
    my ( $Self, %Param ) = @_;

    my %CommonObject;

    # build common objects
    $CommonObject{ActivityObject}         = $Kernel::OM->Get('Kernel::System::ProcessManagement::DB::Activity');
    $CommonObject{ActivityDialogObject}   = $Kernel::OM->Get('Kernel::System::ProcessManagement::DB::ActivityDialog');
    $CommonObject{TransitionActionObject} = $Kernel::OM->Get('Kernel::System::ProcessManagement::DB::TransitionAction');
    $CommonObject{TransitionObject}       = $Kernel::OM->Get('Kernel::System::ProcessManagement::DB::Transition');
    $CommonObject{ProcessObject}          = $Kernel::OM->Get('Kernel::System::ProcessManagement::DB::Process');

    for my $ProcessPart (qw(Process Activity ActivityDialog Transition TransitionAction)) {
        my $ListFunction = $ProcessPart . 'List';
        my $PartList     = $CommonObject{ $ProcessPart . 'Object' }->$ListFunction(
            UserID => 1,
        );
        if ( IsHashRefWithData($PartList) ) {
            for my $ID ( sort keys %{$PartList} ) {
                my $DeleteFunction = $ProcessPart . 'Delete';
                my $Success        = $CommonObject{ $ProcessPart . 'Object' }->$DeleteFunction(
                    ID     => $ID,
                    UserID => 1,
                );
                return if !$Success;
            }
        }
    }
    return 1;
}

sub ProcessImportRaw {
    my ( $Self, %Param ) = @_;

    my %CommonObject;

    # build common objects
    $CommonObject{YAMLObject}             = $Kernel::OM->Get('Kernel::System::YAML');
    $CommonObject{ActivityObject}         = $Kernel::OM->Get('Kernel::System::ProcessManagement::DB::Activity');
    $CommonObject{ActivityDialogObject}   = $Kernel::OM->Get('Kernel::System::ProcessManagement::DB::ActivityDialog');
    $CommonObject{TransitionActionObject} = $Kernel::OM->Get('Kernel::System::ProcessManagement::DB::TransitionAction');
    $CommonObject{TransitionObject}       = $Kernel::OM->Get('Kernel::System::ProcessManagement::DB::Transition');
    $CommonObject{DynamicFieldObject}     = $Kernel::OM->Get('Kernel::System::DynamicField');
    $CommonObject{BackendObject}          = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    $CommonObject{ProcessObject}          = $Kernel::OM->Get('Kernel::System::ProcessManagement::DB::Process');
    $CommonObject{EntityObject}           = $Kernel::OM->Get('Kernel::System::ProcessManagement::DB::Entity');
    $CommonObject{LogObject}              = $Kernel::OM->Get('Kernel::System::Log');

    for my $Needed (qw(Content UserID)) {

        # check needed stuff
        if ( !$Param{$Needed} ) {
            $CommonObject{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my $ProcessData = $CommonObject{YAMLObject}->Load( Data => $Param{Content} );
    if ( ref $ProcessData ne 'HASH' ) {
        return (
            Message =>
                "Couldn't read process configuration file. Please make sure you file is valid.",
        );
    }

    # collect all used fields and make sure they're present
    my @UsedDynamicFields;
    for my $ActivityDialog ( sort keys %{ $ProcessData->{ActivityDialogs} } ) {
        for my $FieldName (
            sort
            keys %{ $ProcessData->{ActivityDialogs}->{$ActivityDialog}->{Config}->{Fields} }
            )
        {
            if ( $FieldName =~ s{DynamicField_(\w+)}{$1}xms ) {
                push @UsedDynamicFields, $FieldName;
            }
        }
    }

    # get all present dynamic fields and check if the fields used in the config are beyond them
    my $DynamicFieldList = $CommonObject{DynamicFieldObject}->DynamicFieldList(
        ResultType => 'HASH',
    );
    my @PresentDynamicFieldNames = values %{$DynamicFieldList};

    my @MissingDynamicFieldNames;
    for my $UsedDynamicFieldName (@UsedDynamicFields) {
        if ( !grep { $_ eq $UsedDynamicFieldName } @PresentDynamicFieldNames ) {
            push @MissingDynamicFieldNames, $UsedDynamicFieldName;
        }
    }

    my %NewAddedDynamicFields;

    # add missing dynamic fields, those have to be deleted manually later
    DYNAMICFIELDNAME:
    for my $DynamicFieldName (@MissingDynamicFieldNames) {
        next DYNAMICFIELDNAME if $NewAddedDynamicFields{$DynamicFieldName};
        my $ID = $CommonObject{DynamicFieldObject}->DynamicFieldAdd(
            InternalField => 0,
            Name          => $DynamicFieldName,
            Label         => $DynamicFieldName,
            FieldOrder    => 10000,
            FieldType     => 'Text',
            ObjectType    => 'Ticket',
            Config        => {
                DefaultValue => '',
            },
            Reorder => 0,
            ValidID => 1,
            UserID  => 1,
        );
        if ($ID) {
            $NewAddedDynamicFields{$DynamicFieldName} = 1;
        }
    }

    # make sure all activities and dialogs are present
    my @UsedActivityDialogs;
    for my $ActivityEntityID ( @{ $ProcessData->{Process}->{Activities} } ) {
        if ( ref $ProcessData->{Activities}->{$ActivityEntityID} ne 'HASH' ) {
            return (
                Message => "Missing data for Activity $ActivityEntityID.",
            );
        }
        else {
            for my $UsedActivityDialog (
                @{ $ProcessData->{Activities}->{$ActivityEntityID}->{ActivityDialogs} }
                )
            {
                push @UsedActivityDialogs, $UsedActivityDialog;
            }
        }
    }

    for my $ActivityDialogEntityID (@UsedActivityDialogs) {
        if ( ref $ProcessData->{ActivityDialogs}->{$ActivityDialogEntityID} ne 'HASH' ) {
            return (
                Message => "Missing data for ActivityDialog $ActivityDialogEntityID.",
            );
        }
    }

    # make sure all transitions are present
    for my $TransitionEntityID ( @{ $ProcessData->{Process}->{Transitions} } ) {
        if ( ref $ProcessData->{Transitions}->{$TransitionEntityID} ne 'HASH' ) {
            return (
                Message => "Missing data for Transition $TransitionEntityID.",
            );
        }
    }

    # make sure all transition actions are present
    for my $TransitionActionEntityID ( @{ $ProcessData->{Process}->{TransitionActions} } ) {
        if ( ref $ProcessData->{TransitionActions}->{$TransitionActionEntityID} ne 'HASH' ) {
            return (
                Message => "Missing data for TransitionAction $TransitionActionEntityID.",
            );
        }
    }

    my %EntityMapping;
    my %PartNameMap = (
        Activity         => 'Activities',
        ActivityDialog   => 'ActivityDialogs',
        Transition       => 'Transitions',
        TransitionAction => 'TransitionActions'
    );

    # keep entities
    $EntityMapping{Process}->{ $ProcessData->{Process}->{EntityID} } = $ProcessData->{Process}->{EntityID};

    for my $PartName (qw(Activity ActivityDialog Transition TransitionAction)) {
        for my $PartEntityID ( sort keys %{ $ProcessData->{ $PartNameMap{$PartName} } } ) {
            $EntityMapping{ $PartNameMap{$PartName} }->{$PartEntityID} = $PartEntityID;
        }

        # make sure that all entity mapping parts are defined as hash references
        $EntityMapping{ $PartNameMap{$PartName} } //= {}
    }

    # invert the entity mappings, this is needed as we need to check if the new entities exists:
    #    for non overwriting processes they must not exists and new records must be generated,
    #    for overwriting processes it might happens that one record does not exists and it needs
    #    to be created before it is updated
    # if new entities are to be created they will be using minimal data and updated with real data
    #    later, this way overwriting and non overwriting processes will share the same logic
    %{ $EntityMapping{Process} }           = reverse %{ $EntityMapping{Process} };
    %{ $EntityMapping{Activities} }        = reverse %{ $EntityMapping{Activities} };
    %{ $EntityMapping{ActivityDialogs} }   = reverse %{ $EntityMapping{ActivityDialogs} };
    %{ $EntityMapping{Transitions} }       = reverse %{ $EntityMapping{Transitions} };
    %{ $EntityMapping{TransitionActions} } = reverse %{ $EntityMapping{TransitionActions} };

    my %AddedEntityIDs;

    # get all processes
    my $ProcessList = $CommonObject{ProcessObject}->ProcessList(
        UseEntities => 1,
        UserID      => $Param{UserID},
    );

    # check if processes exists otherwise create them
    for my $ProcessEntityID ( sort keys %{ $EntityMapping{Process} } ) {
        if ( !$ProcessList->{$ProcessEntityID} ) {

            # create an empty process
            my $ProcessID = $CommonObject{ProcessObject}->ProcessAdd(
                EntityID      => $ProcessEntityID,
                Name          => 'NewProcess',
                StateEntityID => 'S1',
                Layout        => {},
                Config        => {
                    Path        => {},
                    Description => 'NewProcess',
                },
                UserID => $Param{UserID},
            );
            if ( !$ProcessID ) {
                return $CommonObject{ProcessObject}->_ProcessImportRollBack(
                    AddedEntityIDs => \%AddedEntityIDs,
                    UserID         => $Param{UserID},
                    Message        => 'Process '
                        . $ProcessData->{Process}->{Name}
                        . ' could not be added. Stopping import!',
                );
            }

            # remember added entity
            $AddedEntityIDs{Process}->{$ProcessEntityID} = $ProcessID;
        }
    }

    my %PartConfigMap = (
        Activity       => {},
        ActivityDialog => {
            DescriptionShort => 'NewActivityDialog',
            Fields           => {},
            FieldOrder       => [],
        },
        Transition => {
            Condition => {},
        },
        TransitionAction => {
            Module => 'NewTransitionAction',
            Config => {},
        },
    );

    # create missing process parts
    for my $PartName (qw(Activity ActivityDialog Transition TransitionAction)) {

        my $PartListFunction = $PartName . 'List';
        my $PartAddFunction  = $PartName . 'Add';
        my $PartObject       = $PartName . 'Object';

        # get all part items
        my $PartsList = $CommonObject{$PartObject}->$PartListFunction(
            UseEntities => 1,
            UserID      => $Param{UserID},
        );

        # check if part exists otherwise create them
        for my $PartEntityID ( sort keys %{ $EntityMapping{ $PartNameMap{$PartName} } } ) {
            if ( !$PartsList->{$PartEntityID} ) {

                # create an empty part
                my $PartID = $CommonObject{$PartObject}->$PartAddFunction(
                    EntityID => $PartEntityID,
                    Name     => "New$PartName",
                    Config   => $PartConfigMap{$PartName},
                    UserID   => $Param{UserID},
                );
                if ( !$PartID ) {
                    return $CommonObject{ProcessObject}->_ProcessImportRollBack(
                        AddedEntityIDs => \%AddedEntityIDs,
                        UserID         => $Param{UserID},
                        Message        => "$PartName "
                            . $ProcessData->{ $PartNameMap{$PartName} }->{$PartEntityID}->{Name}
                            . ' could not be added. Stopping import!',
                    );
                }

                # remember added entity
                $AddedEntityIDs{ $PartNameMap{$PartName} }->{$PartEntityID} = $PartID;
            }
        }
    }

    # set definitive EntityIDs (now EntityMapping has the real entities)
    my $UpdateResult = $CommonObject{ProcessObject}->_ImportedEntitiesUpdate(
        ProcessData   => $ProcessData,
        EntityMapping => \%EntityMapping,
    );

    if ( !$UpdateResult->{Success} ) {
        return $CommonObject{ProcessObject}->_ProcessImportRollBack(
            AddedEntityIDs => \%AddedEntityIDs,
            UserID         => $Param{UserID},
            Message        => $UpdateResult->{Message},
        );
    }

    $ProcessData = $UpdateResult->{ProcessData};

    # invert the entity mappings again for easy lookup as keys:
    %{ $EntityMapping{Process} }           = reverse %{ $EntityMapping{Process} };
    %{ $EntityMapping{Activities} }        = reverse %{ $EntityMapping{Activities} };
    %{ $EntityMapping{ActivityDialogs} }   = reverse %{ $EntityMapping{ActivityDialogs} };
    %{ $EntityMapping{Transitions} }       = reverse %{ $EntityMapping{Transitions} };
    %{ $EntityMapping{TransitionActions} } = reverse %{ $EntityMapping{TransitionActions} };

    # update all entities with real data
    # update process
    for my $ProcessEntityID ( sort keys %{ $EntityMapping{Process} } ) {
        my $Process = $CommonObject{ProcessObject}->ProcessGet(
            EntityID => $ProcessEntityID,
            UserID   => $Param{UserID},
        );
        my $Success = $CommonObject{ProcessObject}->ProcessUpdate(
            %{ $ProcessData->{Process} },
            ID     => $Process->{ID},
            UserID => $Param{UserID},
        );
        if ( !$Success ) {
            return $CommonObject{ProcessObject}->_ProcessImportRollBack(
                AddedEntityIDs => \%AddedEntityIDs,
                UserID         => $Param{UserID},
                Message        => "Process: $ProcessEntityID could not be updated. "
                    . "Stopping import!",
            );
        }
    }

    # update all other process parts
    for my $PartName (qw(Activity ActivityDialog Transition TransitionAction)) {

        my $PartGetFunction    = $PartName . 'Get';
        my $PartUpdateFunction = $PartName . 'Update';
        my $PartObject         = $PartName . 'Object';

        for my $PartEntityID ( sort keys %{ $EntityMapping{ $PartNameMap{$PartName} } } ) {
            my $Part = $CommonObject{$PartObject}->$PartGetFunction(
                EntityID => $PartEntityID,
                UserID   => $Param{UserID}
            );
            my $Success = $CommonObject{$PartObject}->$PartUpdateFunction(
                %{ $ProcessData->{ $PartNameMap{$PartName} }->{$PartEntityID} },
                ID     => $Part->{ID},
                UserID => $Param{UserID},
            );
            if ( !$Success ) {
                return $CommonObject{ProcessObject}->_ProcessImportRollBack(
                    AddedEntityIDs => \%AddedEntityIDs,
                    UserID         => $Param{UserID},
                    Message        => "$PartName: $PartEntityID could not be updated. "
                        . " Stopping import!",
                );
            }
        }
    }

    return (
        Message => 'Process "'
            . $ProcessData->{Process}->{Name}
            . '" and all its data has been imported successfully.',
        Success => 1,
    );
}

sub ProcessTicketDeleteAll {
    my ( $Self, %Param ) = @_;

    my $ProcessIDDF = $Kernel::OM->Get('Kernel::Config')->Get('Process::DynamicFieldProcessManagementProcessID');

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # search all tickets
    my @TicketIDs = $TicketObject->TicketSearch(
        Result                      => 'ARRAY',
        UserID                      => 1,
        SortBy                      => 'Age',
        OrderBy                     => 'Up',
        ContentSearch               => 'OR',
        FullTextIndex               => 1,
        "DynamicField_$ProcessIDDF" => {
            Like => '****',
        },
    );

    TICKETID:
    for my $TicketID (@TicketIDs) {

        next TICKETID if !$TicketID;

        next TICKETID if $TicketID eq 1 && $Param{ExceptWelcome};

        # get ticket details
        my %Ticket = $TicketObject->TicketGet(
            TicketID => $TicketID,
            UserID   => 1,
        );

        # check if ticket exists
        next TICKETID if ( !%Ticket );

        # delete ticket
        my $Success = $TicketObject->TicketDelete(
            TicketID => $TicketID,
            UserID   => 1,
        );

        return if !$Success;
    }
    return 1;
}

sub GenerateProcessTicket {
    my ( $Self, %Param ) = @_;

    my $TicketID = $Kernel::OM->Get('Kernel::System::Ticket')->TicketCreate(
        Title        => 'Generate Process Ticket' . int rand(10000),
        Queue        => 'Raw',
        Lock         => 'unlock',
        Priority     => '3 normal',
        State        => 'open',
        CustomerID   => '123465',
        CustomerUser => 'customer@example.com',
        OwnerID      => 1,
        UserID       => 1,
    );

    my $ProcessObject = $Kernel::OM->Get('Kernel::System::ProcessManagement::Process');

    my $ProcessList = $ProcessObject->ProcessList(
        ProcessState => [ 'Active', 'FadeAway', 'Inactive' ],
        Interface    => 'all',
    );

    my @SimpleProcessList = sort keys %{$ProcessList};

    my $Rand = int rand $#SimpleProcessList + 1;
    $Rand || 1;
    my $ProcessEntityID = $SimpleProcessList[$Rand];

    my $Success = $ProcessObject->ProcessTicketProcessSet(
        ProcessEntityID => $ProcessEntityID,
        TicketID        => $TicketID,
        UserID          => 1,
    );

    my $Process = $ProcessObject->ProcessGet(
        ProcessEntityID => $ProcessEntityID,
    );

    my @SimpleActiviyList = sort keys %{ $Process->{Path} };

    $Rand = int rand $#SimpleActiviyList + 1;
    $Rand || 1;
    my $ActivityEntityID = $SimpleActiviyList[$Rand];

    $Success = $ProcessObject->ProcessTicketActivitySet(
        ProcessEntityID  => $ProcessEntityID,
        ActivityEntityID => $ActivityEntityID,
        TicketID         => $TicketID,
        UserID           => 1,
    );

    return {
        TicketID         => $TicketID,
        ProcessEntityID  => $ProcessEntityID,
        ActivityEntityID => $ActivityEntityID,
    };
}

sub ProcessDeploy {
    my ( $Self, %Param ) = @_;

    my $Location = $Kernel::OM->Get('Kernel::Config')->Get('Home')
        . '/Kernel/Config/Files/ZZZProcessManagement.pm';

    my $ProcessDump = $Kernel::OM->Get('Kernel::System::ProcessManagement::DB::Process')->ProcessDump(
        ResultType => 'FILE',
        Location   => $Location,
        UserID     => 1,
    );

    if ($ProcessDump) {

        my $Success = $Kernel::OM->Get('Kernel::System::ProcessManagement::DB::Entity')->EntitySyncStatePurge(
            UserID => 1,
        );

        if ( !$Success ) {

            return {
                Success => 0,
                Message => "There was an error setting the entity sync status.",
            };
        }

        return {
            Success => 1,
        };
    }

    # show error if can't sync
    return {
        Success => 0,
        Message => "There was an error synchronizing the processes.",
    };
}

=item ProcessSearch()

To search Processes

    my %List = $DevProcessObject->ACLSearch(
        Name  => '*some*', # also 'hans+huber' possible
        Valid => 1,        # not required
    );

=cut

sub ProcessSearch {
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
        FROM pm_process
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
        SQL => $SQL,
    );

    my %Processes;

    # fetch the result
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Processes{ $Row[0] } = $Row[1];
    }

    return %Processes;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is is a component of the CRDevTools project (L<https://github.com/carlosfrodriguez/CRDevTools/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
