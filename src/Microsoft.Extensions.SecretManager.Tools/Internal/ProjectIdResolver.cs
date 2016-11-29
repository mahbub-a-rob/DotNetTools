// Copyright (c) .NET Foundation. All rights reserved.
// Licensed under the Apache License, Version 2.0. See License.txt in the project root for license information.

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Tools.Internal;

namespace Microsoft.Extensions.SecretManager.Tools.Internal
{
    public class ProjectIdResolver : IDisposable
    {
        private const string TargetsFileName = "FindUserSecretsProperty.targets";
        private readonly ILogger _logger;
        private readonly string _workingDirectory;
        private readonly List<string> _tempFiles = new List<string>();

        public ProjectIdResolver(ILogger logger, string workingDirectory)
        {
            _workingDirectory = workingDirectory;
            _logger = logger;
        }

        public string Resolve(string project, string configuration = "Debug")
        {
            var finder = new MsBuildProjectFinder(_workingDirectory);
            var projectFile = finder.FindMsBuildProject(project);

            _logger.LogDebug(Resources.Message_Project_File_Path, projectFile);

            var targetFile = GetTargetFile();
            var outputFile = Path.GetTempFileName();
            _tempFiles.Add(outputFile);

            var args = new[]
            {
                "msbuild",
                targetFile,
                "/nologo",
                "/t:_FindUserSecretsProperty",
                $"/p:Project={projectFile}",
                $"/p:OutputFile={outputFile}",
                $"/p:Configuration={configuration}"
            };
            var psi = new ProcessStartInfo
            {
                FileName = DotNetMuxer.MuxerPathOrDefault(),
                Arguments = ArgumentEscaper.EscapeAndConcatenate(args),
                RedirectStandardOutput = true,
                RedirectStandardError = true
            };
            var process = Process.Start(psi);
            process.WaitForExit();

            if (process.ExitCode != 0)
            {
                _logger.LogDebug(process.StandardOutput.ReadToEnd());
                _logger.LogDebug(process.StandardError.ReadToEnd());
                throw new InvalidOperationException(Resources.FormatError_ProjectFailedToLoad(projectFile));
            }

            var id = File.ReadAllText(outputFile)?.Trim();
            if (string.IsNullOrEmpty(id))
            {
                throw new InvalidOperationException(Resources.FormatError_ProjectMissingId(projectFile));
            }

            return id;
        }

        public void Dispose()
        {
            foreach (var file in _tempFiles)
            {
                TryDelete(file);
            }
        }

        private string GetTargetFile()
        {
            var assemblyDir = Path.GetDirectoryName(GetType().GetTypeInfo().Assembly.Location);

            // targets should be in one of these locations, depending on test setup and tools installation
            var searchPaths = new[]
            {
				// next to deps.json file
                AppContext.BaseDirectory,
				// next to assembly
				assemblyDir, 
				// inside the nupkg
                Path.Combine(assemblyDir, "../../tools"), 
				// theoretically possible if NuGet puts deps.json is inside the nupkg
				Path.Combine(AppContext.BaseDirectory, "../../tools"), 
            };

            return searchPaths
                .Select(dir => Path.Combine(dir, TargetsFileName))
                .Where(File.Exists)
                .First();
        }

        private static void TryDelete(string file)
        {
            try
            {
                if (File.Exists(file))
                {
                    File.Delete(file);
                }
            }
            catch
            {
                // whatever
            }
        }
    }
}