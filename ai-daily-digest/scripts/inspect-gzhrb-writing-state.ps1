param(
    [Parameter(Mandatory)][string]$ArticlePath,
    [string]$WorkitemPath,
    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'validate-gzhrb-writing-state.ps1')

function Format-Bool {
    param([bool]$Value)

    if ($Value) {
        return 'yes'
    }

    return 'no'
}

function Join-OrNone {
    param([AllowNull()]$Values)

    $items = @($Values)
    if ($items.Count -eq 0) {
        return '<none>'
    }

    return ($items -join ', ')
}

function Format-ProvenanceSummary {
    param(
        [Parameter(Mandatory)]$ProvenanceState,
        [Parameter(Mandatory)][string]$Label
    )

    if ($null -eq $ProvenanceState) {
        return "${Label}: missing"
    }

    $validText = if ($ProvenanceState.valid) { 'valid' } else { 'invalid' }
    return "${Label}: $validText (exists=$(Format-Bool -Value $ProvenanceState.exists), skill=$(Format-Bool -Value $ProvenanceState.skill_name_match), status=$(Format-Bool -Value $ProvenanceState.status_match), output=$(Format-Bool -Value $ProvenanceState.output_path_match))"
}

function Get-GzhrbWritingStateReport {
    param(
        [Parameter(Mandatory)][string]$ArticlePath,
        [string]$WorkitemPath
    )

    $validation = Get-GzhrbWritingStateValidation -ArticlePath $ArticlePath -WorkitemPath $WorkitemPath
    $logLines = @()
    foreach ($entry in @($validation.execution_log_tail)) {
        $logLines += "- $($entry.timestamp) | $($entry.action) | $($entry.updated_by)"
    }

    if ($logLines.Count -eq 0) {
        $logLines = @('- <none>')
    }

    $khazixProvenanceLine = Format-ProvenanceSummary -Label 'Khazix provenance' -ProvenanceState $validation.provenance_state.khazix_execution
    $wechatProvenanceLine = Format-ProvenanceSummary -Label 'Wechat provenance' -ProvenanceState $validation.provenance_state.wechat_execution
    $illustrationProvenanceLine = Format-ProvenanceSummary -Label 'Illustration provenance' -ProvenanceState $validation.provenance_state.illustration_execution

    return @(
        "Article path           : $ArticlePath"
        "Workitem path          : $($validation.workitem_path)"
        "Declared stage         : $($validation.declared_stage)"
        "Evidence stage         : $($validation.evidence_stage)"
        "State matches evidence : $($validation.state_matches_evidence)"
        "Topic approval         : $(Format-Bool -Value $validation.approval_state.topic_selected)"
        "Khazix approval        : $(Format-Bool -Value $validation.approval_state.khazix_approved)"
        "Wechat approval        : $(Format-Bool -Value $validation.approval_state.wechat_approved)"
        "Illustration approval  : $(Format-Bool -Value $validation.approval_state.illustrations_approved)"
        $khazixProvenanceLine
        $wechatProvenanceLine
        $illustrationProvenanceLine
        "Khazix status          : $($validation.writing_state.khazix.status)"
        "Wechat status          : $($validation.writing_state.wechat.status)"
        "Ready for postwriting  : $($validation.is_ready_for_postwriting)"
        "Missing files          : $(Join-OrNone -Values $validation.missing_evidence.files)"
        "Missing provenance     : $(Join-OrNone -Values $validation.missing_evidence.provenance)"
        "Missing approvals      : $(Join-OrNone -Values $validation.missing_evidence.approvals)"
        "Next step              : $($validation.next_step)"
        "Execution log tail     :"
        ($logLines -join "`n")
    ) -join "`n"
}

if ($MyInvocation.InvocationName -ne '.') {
    $validation = Get-GzhrbWritingStateValidation -ArticlePath $ArticlePath -WorkitemPath $WorkitemPath
    if ($AsJson) {
        $validation | ConvertTo-Json -Depth 8
    } else {
        Get-GzhrbWritingStateReport -ArticlePath $ArticlePath -WorkitemPath $WorkitemPath
    }
}
