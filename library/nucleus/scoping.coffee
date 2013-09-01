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

_ = require "lodash"
uuid = require "node-uuid"
assert = require "assert"
connect = require "connect"
moment = require "moment"
logger = require "winston"
events = require "eventemitter2"
colors = require "colors"
nconf = require "nconf"
paths = require "path"
util = require "util"
fs = require "fs"

{spawn} = require "child_process"
{rmdirSyncRecursive} = require "wrench"
{mkdirSyncRecursive} = require "wrench"

# This is a primary gateway interface for the framework. This class
# provides methods and routines necessary to bootstrap the framework
# and the end user application constructed within the framework. It
# is both an abstract base class as well as a ready to use bootstrap.
# Please refer to the documentation of the methods for more info.
module.exports.Scope = class Scope extends events.EventEmitter2

    # Construct a new scope, using the supplied tag (a short name)
    # and a synopsis (short description of the scope) parameters.
    # The constructor of the scope should only associate the data.
    # The scope startup logic should be implemented in the method.
    constructor: (@tag, synopsis) ->
        assert _.isString(@tag), "invalid tag"
        @synopsis = synopsis if _.isString synopsis
        @directory = @constructor.DIRECTORY or __dirname
        initializer = _.find arguments, _.isFunction
        initializer?.call this, @tag, synopsis
        @pushToRegistry yes, @tag.toUpperCase()

    # Push the current scope instance into the global registry
    # of scopes, unless this instance already exists there. This
    # registry exists for easing looking up the scope by its tag.
    # You may provide a number of aliaes for this scope instance.
    pushToRegistry: (override, aliases...) ->
        registry = @constructor.REGISTRY ?= {}
        existent = (tag) -> tag of registry and not override
        valids = _.filter aliases, (a) -> not existent(a)
        registry[@tag] = this unless existent @tag
        registry[alias] = this for alias in valids

    # Lookup the possibly existent scope with one of the following
    # alises as a tag. If no matching candidates exist, the method
    # will fail with en error, since this is considered a critical
    # error. You should always use this method instead of manual.
    @lookupOrFail: (aliases...) ->
        registry = @REGISTRY ?= {}; joined = aliases.join(", ")
        notFound = "Could not found any of #{joined} scoped"
        logger.info "Looking up any of this scopes: %s".grey, joined
        found = (v for own k, v of registry when k in aliases)
        throw new Error notFound unless found.length > 0
        assert.ok _.isObject scope = _.head(found); scope

    # Get a concatenated path to the unique path designed by the
    # combination of prefix and a unique identificator generated by
    # employing the UUID v4 format. If unique param is set to false
    # than the path will be set to prefix without the unique part.
    envPath: (basis, prefix, unique=uuid.v4()) ->
        dirs = nconf.get("env:dirs") or []
        unknown = "Env dir #{basis} is not managed"
        assert _.isString(prefix), "invalid prefix"
        throw new Error unknown unless basis in dirs
        prefix = prefix + "-" + unique if unique
        return paths.join basis, prefix

    # This method is responsible for starting up the scope object.
    # This means initialization of all its necessary routines and
    # setting up whatever this scope needs to set. The default
    # implementation takes care only of loading the proper config.
    incorporate: (kernel) ->
        nconf.defaults(@defaults or @constructor.DEFAULTS or {})
        nconf.overrides(@overrides or @constructor.OVERRIDES or {})
        fpath = "#{nconf.get "layout:config"}/#{@tag}.json"
        logger.info "Incorporating up the #{@tag.bold} scope".cyan
        logger.info "Assuming the #{fpath.underline} config".cyan
        exists = fs.existsSync fpath; nconf.file fpath if exists
        for directory in nconf.get("env:dirs") or []
            mode = nconf.get("env:mode")
            msg = "Environment mkdir at %s with 0%s mode".yellow
            logger.info msg, directory.underline, mode.toString 8
            mkdirSyncRecursive directory, mode

    # This method is responsible for shutting down the scope object.
    # This means stripping down all the necessary routines and other
    # resources that are mandated by this this scope object. Default
    # implementation does not do almost anything, so it is up to you.
    disperse: (kernel) ->
        fpath = "#{nconf.get "layout:config"}/#{@tag}.json"
        logger.info "Dissipating the #{@tag.bold} scope".grey
        logger.info "Used #{fpath.underline} as config".grey
        assert _.isArray preserve = nconf.get "env:preserve"
        for directory in nconf.get("env:dirs") or []
            continue if directory in preserve
            msg = "Wiping out the env directory at %s".yellow
            logger.info msg, directory.underline
            rmdirSyncRecursive directory, yes
