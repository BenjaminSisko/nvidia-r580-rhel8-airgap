% MATLAB readiness inventory for R2024a/R2024b/R2026a (Linux x86_64 target).
% See docs/MATLAB-OFFLINE.md. No installation, compilation, workers, driver
% changes, downloads, environment changes, or forward-compatibility enablement.
%
% Optional input struct in the caller workspace:
%   matlabReadinessOptions.RunSmallTest = false;   % default; current/default GPU
%   matlabReadinessOptions.RunValidateGPU = false; % default; current/default GPU
%   matlabReadinessOptions.ExpectedGPUCount = [];  % set only after site inventory
% Result: matlabReadinessReport. Nothing is written to disk by this script.
% Optional tests initialize/use one GPU; run in a fresh, idle MATLAB session.

if ~exist('matlabReadinessOptions', 'var')
    matlabReadinessOptions = struct();
end
matlabReadinessReport = mrCollectReadiness(matlabReadinessOptions);
fprintf('\nMATLAB readiness inventory: %s, %s\n', ...
    matlabReadinessReport.matlab.release, matlabReadinessReport.host.architecture);
fprintf('Toolboxes listed: %d; GPUs detected: %s\n', ...
    numel(matlabReadinessReport.products), ...
    mat2str(matlabReadinessReport.gpu.detectedCount));
fprintf('Small numerical test: %s; validateGPU: %s\n', ...
    matlabReadinessReport.smallTest.status, matlabReadinessReport.validation.status);
for matlabReadinessNoteIndex = 1:numel(matlabReadinessReport.notes)
    fprintf('NOTE: %s\n', matlabReadinessReport.notes{matlabReadinessNoteIndex});
end
fprintf(['Inspect matlabReadinessReport; this inventory does not accept all ' ...
    'toolboxes, code generation, or production workloads.\n']);

function report = mrCollectReadiness(options)
    if ~isstruct(options) || ~isscalar(options)
        error('matlabReadiness:InvalidOptions', 'Options must be a scalar struct.');
    end
    allowed = {'RunSmallTest', 'RunValidateGPU', 'ExpectedGPUCount'};
    if ~all(ismember(fieldnames(options), allowed))
        error('matlabReadiness:InvalidOptions', 'Unknown readiness option.');
    end
    options = mrDefault(options, 'RunSmallTest', false);
    options = mrDefault(options, 'RunValidateGPU', false);
    options = mrDefault(options, 'ExpectedGPUCount', []);
    validateattributes(options.RunSmallTest, {'logical'}, {'scalar'});
    validateattributes(options.RunValidateGPU, {'logical'}, {'scalar'});
    if ~isempty(options.ExpectedGPUCount)
        validateattributes(options.ExpectedGPUCount, {'numeric'}, ...
            {'scalar', 'integer', 'positive', 'finite'});
    end

    report = struct();
    report.schemaVersion = 1;
    report.collectedUTC = char(datetime('now', 'TimeZone', 'UTC', ...
        'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));
    report.options = options;
    report.matlab = struct('version', version, 'release', version('-release'));
    report.host = struct('computer', computer, 'architecture', computer('arch'), ...
        'isUnix', isunix, 'isMac', ismac, 'os', struct(), 'kernel', '');
    report.products = ver;
    report.errors = struct('stage', {}, 'identifier', {});
    report.notes = {};
    report.addons = struct([]);
    report.compiler = struct('status', 'not-inspected', 'selectedCpp', struct([]));
    report.gpu = struct('status', 'not-inspected', 'detectedCount', [], ...
        'devices', struct([]), 'forwardCompatibilityEnabled', []);
    report.smallTest = struct('status', 'not-requested');
    report.validation = struct('status', 'not-requested', 'available', false);

    % Fixed OS identity fields only: no hostname, addresses, account, license
    % identifiers, environment values, UUIDs, MATLAB root or home directories.
    if isunix && ~ismac
        try
            text = fileread('/etc/os-release');
            for field = {'PRETTY_NAME', 'ID', 'VERSION_ID'}
                token = regexp(text, ['(?m)^' field{1} '=(.*)$'], 'tokens', 'once');
                if ~isempty(token)
                    report.host.os.(field{1}) = strrep(strtrim(token{1}), '"', '');
                end
            end
            report.host.kernel = strtrim(fileread('/proc/sys/kernel/osrelease'));
        catch issue
            report.errors(end+1) = mrError('os-identity', issue);
        end
    end
    if ~strcmp(report.host.architecture, 'glnxa64')
        report.notes{end+1} = 'This is not the intended Linux x86_64 target.';
    end
    if ~isfield(report.host.os, 'ID') || ~strcmp(report.host.os.ID, 'rhel') || ...
            ~isfield(report.host.os, 'VERSION_ID') || ...
            ~strcmp(report.host.os.VERSION_ID, '8.10')
        report.notes{end+1} = 'RHEL 8.10 identity is not confirmed by this inventory.';
    end

    % Presence flags only; never copy environment values into the report.
    envNames = {'LD_LIBRARY_PATH', 'MW_NVCC_PATH', 'CUDA_PATH', ...
        'NVIDIA_CUDNN', 'NVIDIA_TENSORRT', 'MW_CUDA_FORWARD_COMPATIBILITY'};
    report.environmentOverridesPresent = struct();
    for index = 1:numel(envNames)
        report.environmentOverridesPresent.(envNames{index}) = ...
            ~isempty(getenv(envNames{index}));
    end
    if report.environmentOverridesPresent.MW_NVCC_PATH
        report.notes{end+1} = 'MW_NVCC_PATH is set; review before MATLAB GPU tests.';
    end

    try
        installed = matlab.addons.installedAddons;
        columns = intersect({'Name', 'Version', 'Enabled'}, ...
            installed.Properties.VariableNames, 'stable');
        if ~isempty(columns)
            report.addons = table2struct(installed(:, columns));
        end
    catch issue
        report.errors(end+1) = mrError('installed-addons', issue);
    end
    try
        configurations = mex.getCompilerConfigurations('C++', 'Selected');
        if isempty(configurations)
            report.compiler.status = 'no-cpp-compiler-selected';
            report.notes{end+1} = 'Select a supported C++ compiler before mexcuda/codegen.';
        else
            for index = 1:numel(configurations)
                report.compiler.selectedCpp(index).Name = configurations(index).Name;
                report.compiler.selectedCpp(index).Version = configurations(index).Version;
                report.compiler.selectedCpp(index).Manufacturer = configurations(index).Manufacturer;
            end
            report.compiler.status = 'selected-configuration-only-not-compiled';
        end
    catch issue
        report.compiler.status = 'inspection-failed';
        report.errors(end+1) = mrError('compiler-configuration', issue);
    end

    report.capabilities = struct( ...
        'parallelComputingToolboxInstalled', any(strcmp({report.products.Name}, ...
            'Parallel Computing Toolbox')), ...
        'deepLearningToolboxInstalled', any(strcmp({report.products.Name}, ...
            'Deep Learning Toolbox')), ...
        'matlabCoderInstalled', any(strcmp({report.products.Name}, 'MATLAB Coder')), ...
        'gpuCoderInstalled', any(strcmp({report.products.Name}, 'GPU Coder')), ...
        'mexcudaFunctionAvailable', exist('mexcuda', 'file') ~= 0);
    report.validation.available = exist('validateGPU', 'file') ~= 0;
    if ~report.capabilities.parallelComputingToolboxInstalled
        report.gpu.status = 'parallel-computing-toolbox-missing';
        report.notes{end+1} = 'Parallel Computing Toolbox is required for MATLAB GPU work.';
    else
        try
            % No gpuDevice(index), reset, parpool or allocation here. This
            % inventory may initialize the driver and require a PCT license.
            devices = gpuDeviceTable;
            safeColumns = intersect({'Index', 'Name', 'ComputeCapability', ...
                'DeviceAvailable', 'DeviceSelected'}, ...
                devices.Properties.VariableNames, 'stable');
            report.gpu.devices = table2struct(devices(:, safeColumns));
            report.gpu.detectedCount = height(devices);
            report.gpu.status = 'enumerated-not-compute-tested';
            report.gpu.forwardCompatibilityEnabled = ...
                parallel.gpu.enableCUDAForwardCompatibility;
            if isempty(devices)
                report.notes{end+1} = 'No GPU was detected in this MATLAB process.';
            elseif any(~devices.DeviceAvailable)
                report.notes{end+1} = 'At least one detected GPU is unavailable to this MATLAB session.';
            end
            if ~isempty(options.ExpectedGPUCount) && ...
                    height(devices) ~= options.ExpectedGPUCount
                report.notes{end+1} = 'Detected count differs from the operator-confirmed expected count.';
            end
        catch issue
            report.gpu.status = 'enumeration-failed';
            report.errors(end+1) = mrError('gpu-enumeration', issue);
            report.notes{end+1} = 'GPU enumeration failed; inspect driver, release, toolbox and licensing.';
        end
    end
    if any(strcmp(report.matlab.release, {'2024a', '2024b'}))
        report.notes{end+1} = ['R2024 has no native Blackwell GPU support; ' ...
            'external CUDA 12.8 does not replace MATLAB supplied libraries.'];
    end
    if isequal(report.gpu.forwardCompatibilityEnabled, true)
        report.notes{end+1} = ['Forward compatibility was already enabled; ' ...
            'this script did not enable it. Numerical acceptance remains required.'];
    end

    if options.RunSmallTest
        if ~report.capabilities.parallelComputingToolboxInstalled
            report.smallTest.status = 'blocked-missing-parallel-computing-toolbox';
        else
            try
                device = gpuDevice; % Use the current GPU, or initialize default.
                a = reshape(1:4096, 64, 64) ./ 4096;
                reference = a * a.';
                input = gpuArray(a);
                result = gather(input * input.');
                relativeError = norm(result-reference, 'fro') / max(norm(reference, 'fro'), eps);
                report.smallTest = struct('status', 'failed-numerical-tolerance', ...
                    'deviceIndex', device.Index, 'deviceName', device.Name, ...
                    'relativeFrobeniusError', relativeError, 'tolerance', 1e-10, ...
                    'matrixSize', 64, 'numericClass', 'double');
                if isfinite(relativeError) && relativeError <= 1e-10
                    report.smallTest.status = 'passed-small-matrix-only';
                end
                clear input result
            catch issue
                report.smallTest.status = 'failed';
                report.errors(end+1) = mrError('small-gpu-test', issue);
            end
        end
    end
    if options.RunValidateGPU
        if ~report.validation.available
            report.validation.status = 'unavailable-in-this-release-or-installation';
        else
            try
                % validateGPU prints failures and may not throw. Capture only
                % outcome counts; do not retain raw local paths/environment.
                output = evalc('validateGPU');
                failed = numel(regexp(output, '\.{3,}\s*FAILED\b', 'match'));
                passed = numel(regexp(output, '\.{3,}\s*PASSED\b', 'match'));
                skipped = numel(regexp(output, '\.{3,}\s*SKIPPED\b', 'match'));
                report.validation.failedChecks = failed;
                report.validation.passedChecks = passed;
                report.validation.skippedChecks = skipped;
                if failed > 0
                    report.validation.status = 'reported-failed-checks';
                elseif passed > 0
                    report.validation.status = 'reported-checks-passed-review-skips';
                else
                    report.validation.status = 'completed-output-unparsed-run-manually';
                end
                clear output
            catch issue
                report.validation.status = 'failed';
                report.errors(end+1) = mrError('validateGPU', issue);
            end
        end
    end
    report.notes{end+1} = ['GPU Coder external cuDNN 8.9 versus Blackwell cuDNN 9.7+ ' ...
        'is unresolved; see the offline guide.'];
    report.notes{end+1} = ['Product presence is not a license checkout or workload test. ' ...
        'No all-toolbox or multi-GPU acceptance is implied.'];
end

function options = mrDefault(options, name, value)
    if ~isfield(options, name)
        options.(name) = value;
    end
end

function entry = mrError(stage, issue)
    % Error messages can contain account paths or license-server information.
    % Keep only the stage and stable MATLAB identifier in a shareable report.
    entry = struct('stage', stage, 'identifier', issue.identifier);
end
