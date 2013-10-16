###
Copyright (c) 2013, Alexander Cherniuk <ts33kr@gmail.com>
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
###

fs = require "fs"
paths = require "path"
assert = require "assert"
colors = require "colors"
logger = require "winston"

_ = require "lodash"
{rmdirSyncRecursive} = require "wrench"
{spawn} = require "child_process"

# Here follows the definition of a number of constants that define
# the defaults for some of the options, generally for the ones that
# specify directory paths that constitute the directory layout of
# the project. Use one of these instead of hardcoding the defaults!
DEFAULT_LIBRARY = "library"
DEFAULT_ARTIFACT = "artifact"
DEFAULT_DOCUMENTS = "documents"
DEFAULT_MODULES = "node_modules"
DEFAULT_SCOPING = "development"
DEFAULT_LOGGING = "info"

# This method contains a definition for the typical Cakefile for an
# application created within the framework. This very same template
# is also used by the framework itself for the Cakefile of its own.
# This method should satisfy the basic boilerplating needs of apps.
module.exports = ->

    # Here follows the definition of the options required for some of
    # the tasks defined in this Cakefile. Remember that the scope of
    # definition of the options is global to a Cakefile, therefore the
    # options are shared among all of the tasks and the entire file!
    option "-l", "--library [PATH]", "Path to the library sources"
    option "-m", "--modules [PATH]", "Path to the modules directory"
    option "-a", "--artifact [PATH]", "Path to the artifact directory"
    option "-d", "--documents [PATH]", "Path to the documents directory"
    option "-s", "--scoping [SCOPE]", "The name of the scope to boot kernel"
    option "-i", "--logging [LEVEL]", "The level to use for the logging output"
    option "-w", "--watch", "Watch the library sources and recompile"
    option "-g", "--git-hub-pages", "Publish documents to GitHub pages"
    option "-n", "--clean-modules", "Remove node_modules during cleanup"

    # This task launches an instance of application where this task
    # is invoked at. It should be either an application build within
    # the framework or the framework itself (it can be launched all
    # by itself as a standalone). Please refer to the implementation!
    # In terms of scalability - it starts the master server istance.
    task "master", "bootstrap as the master server", (options) ->
        library = options.library or DEFAULT_LIBRARY
        scoping = options.scoping or DEFAULT_SCOPING
        logging = options.logging or DEFAULT_LOGGING
        process.env["NODE_ENV"] = scoping.toString()
        process.env["log:level"] = logging.toString()
        granite = require "#{__dirname}/../../index"
        assert resolved = paths.resolve library or null
        missingLibrary = "missing library: #{resolved}"
        assert _.isObject(granite), "framework failed"
        assert fs.existsSync(library), missingLibrary
        compiled = granite.collectPackages no, library
        assert _.isObject(compiled), "invalid library"
        conf = new Object master: yes, instance: no
        granite.cachedKernel(library).bootstrap conf

    # This task launches an instance of application where this task
    # is invoked at. It should be either an application build within
    # the framework or the framework itself (it can be launched all
    # by itself as a standalone). Please refer to the implementation!
    # In terms of scalability - it starts the application instance.
    task "boot", "bootstrap the framework kernel", (options) ->
        library = options.library or DEFAULT_LIBRARY
        scoping = options.scoping or DEFAULT_SCOPING
        logging = options.logging or DEFAULT_LOGGING
        process.env["NODE_ENV"] = scoping.toString()
        process.env["log:level"] = logging.toString()
        granite = require "#{__dirname}/../../index"
        assert resolved = paths.resolve library or null
        missingLibrary = "missing library: #{resolved}"
        assert _.isObject(granite), "framework failed"
        assert fs.existsSync(library), missingLibrary
        compiled = granite.collectPackages no, library
        assert _.isObject(compiled), "invalid library"
        conf = new Object master: no, instance: yes
        granite.cachedKernel(library).bootstrap conf

    # This is one of the major tasks in this Cakefile, it implements
    # the cleanup of everything that could have been generated by the
    # build system; such as documentation, compiled JavaScript artifact,
    # and every other piece of generated data that the system knows of.
    task "cleanup", "remove everything generated by build", (options) ->
        knm = "clean-modules" of options or Object()
        modules = options.modules or DEFAULT_MODULES
        artifact = options.artifact or DEFAULT_ARTIFACT
        documents = options.documents or DEFAULT_DOCUMENTS
        removing = "Removing everything under %s".yellow
        note = (path) -> logger.warn removing, path
        note artifact; rmdirSyncRecursive artifact, yes
        note documents; rmdirSyncRecursive documents, yes
        (note modules; rmdirSyncRecursive modules, yes) if knm
        logger.info "Finished cleaning everything up".green

    # This is one of the major tasks in this Cakefile, it implements
    # the generation of the documentation for the library, using the
    # Groc documentation tool. The Groc depends on Pygments being set
    # in place, before running. Takes some minor options via CLI call.
    task "documents", "generate the library documentation", (options) ->
        library = options.library or DEFAULT_LIBRARY
        documents = options.documents or DEFAULT_DOCUMENTS
        [pattern, index] = ["#{library}/**/*.coffee", "README.md"]
        parameters = [pattern, "Cakefile", index, "-o", documents]
        parameters.push "--github" if g = "git-hub-pages" of options
        logger.info "Publishing docs to GitHub pages".yellow if g
        assert _.isObject generator = spawn "groc", parameters
        assert _.isObject generator.stdout.pipe process.stdout
        assert _.isObject generator.stderr.pipe process.stderr
        assert _.isObject generator.on "exit", (status) ->
            failure = "Failed to generate documentation".red
            success = "Generated documentation successfuly".green
            logger.error failure if status isnt 0
            logger.info success if status is 0

    # This is one of the major tasks in this Cakefile, it implements
    # the compilatation of the library source code from CoffeeScript
    # to JavaScript, taking into account the supplied options or the
    # assumed defaults if the options are not supplied via CLI call.
    task "compile", "compile CoffeeScript into JavaScript", (options) ->
        library = options.library or DEFAULT_LIBRARY
        artifact = options.artifact or DEFAULT_ARTIFACT
        parameters = ["-c", "-o", artifact, library]
        parameters.unshift "-w" if options.watch?
        watching = "Watching the %s directory".blue
        logger.info watching, library if options.watch?
        assert _.isObject compiler = spawn "coffee", parameters
        assert _.isObject compiler.stdout.pipe process.stdout
        assert _.isObject compiler.stderr.pipe process.stderr
        assert _.isObject compiler.on "exit", (status) ->
            failure = "Failed to compile library".red
            success = "Compiled library successfuly".green
            logger.error failure if status isnt 0
            logger.info success if status is 0
