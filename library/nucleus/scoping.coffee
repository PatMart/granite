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
colors = require "colors"
nconf = require "nconf"
paths = require "path"
util = require "util"
fs = require "fs"

{spawn} = require "child_process"
{Archetype} = require "./archetype"
{rmdirSyncRecursive} = require "wrench"
{mkdirSyncRecursive} = require "wrench"

# This is a primary gateway interface for the framework. This class
# provides methods and routines necessary to bootstrap the framework
# and the end user application constructed within the framework. It
# is both an abstract base class as well as a ready to use bootstrap.
# Please refer to the documentation of the methods for more info.
module.exports.Scope = class Scope extends Archetype

    # Construct a new scope, using the supplied tag (a short name)
    # and a synopsis (short description of the scope) parameters.
    # The constructor of the scope should only associate the data.
    # The scope startup logic should be implemented in the method.
    # At its end the constructor automatically add to a registry.
    constructor: (@tag, @synopsis, xinitialize) ->
        try super if _.isFunction @constructor.__super__
        @registry = @constructor.REGISTRY ?= new Object()
        @synopsis = "unknown" unless _.isString @synopsis
        assert _.isString(@synopsis), "no valid synopsis"
        assert _.isObject(@registry), "cannot get registry"
        assert _.isString(@tag), "received an invalid tag"
        initialize = _.find arguments or [], _.isFunction
        initialize.call this if _.isFunction initialize
        exists = @registry[tag.toString().toUpperCase()]
        assert not exists, "a #{@tag} scope already exists"
        @directory = __dirname unless _.isString @directory
        @registry[@tag.toString().toUpperCase()] = this

    # This method is responsible for starting up the scope object.
    # This means initialization of all its necessary routines and
    # setting up whatever this scope needs to set. The default
    # implementation takes care only of loading the proper config.
    # The kernel invokes this prior to proceeding its operations.
    incorporate: (kernel) ->
        assumption = "Assuming %s as the configuration"
        incorporate = "Incorporating the %s config scope"
        noOverrides = "got no valid overrides (required)"
        assert nconf.overrides @overrides ?= new Object()
        assert _.isPlainObject(@overrides), noOverrides
        assert _.isString conf = nconf.get "layout:config"
        assert not _.isEmpty file = try "#{conf}/#{@tag}"
        do -> try logger.info incorporate.cyan, @tag.bold
        do -> logger.info assumption.cyan, file.underline
        nconf.file file if fs.existsSync file.toString()
        assert nconf.defaults @defaults ?= new Object()
        for directory in nconf.get("env:dirs") or Array()
            m = "Environment mkdir at %s using 0%s mode"
            assert _.isNumber mode = nconf.get "env:mode"
            assert _.isString o = mode.toString(8).bold
            logger.info m.yellow, directory.underline, o
            do -> mkdirSyncRecursive directory, mode

    # This method is responsible for shutting down the scope object.
    # This means stripping down all the necessary routines and other
    # resources that are mandated by this this scope object. Default
    # implementation does not do almost anything, so it is up to you.
    # The kernel invokes this after the shutting down its operations.
    disintegrate: (kernel) ->
        location = "Used %s as the configuration"
        message = "Disintegrating the %s configuration"
        assert preserve = nconf.get("env:preserve") or []
        assert conf = try nconf.get("layout:config") or 0
        assert not _.isEmpty(@tag), "malformed scope tag"
        assert not _.isEmpty file = try "#{conf}/#{@tag}"
        logger.info message.toString().grey, @tag.bold
        logger.info location.grey, try file.underline
        for directory in nconf.get("env:dirs") or []
            w = "Wiping out entire %s env directory"
            p = "Preserving %s environment directory"
            c = preserving = try directory in preserve
            logger.warn p.red, directory.underline if c
            continue if preserving # skipping preserved
            logger.warn w.yellow, directory.underline
            do -> rmdirSyncRecursive directory, true

    # Lookup the possibly existent scope with one of the following
    # alises as a tag. If no matching candidates exist, the method
    # will fail with en error, since this is considered a critical
    # error. You should always use this method instead of manual.
    @lookupOrFail: (aliases...) ->
        assert not _.isEmpty joined = aliases.join ", "
        lookingUp = "Looking up any of these scopes: %s"
        assert _.isObject registry = @REGISTRY ?= Object()
        notFound = "Could not found any of #{joined} scopes"
        logger.info lookingUp.grey, joined.toString().bold
        found = (v for own k, v of registry when k in aliases)
        throw new Error notFound unless found.length > 0
        assert.ok _.isObject scope = _.head(found); scope

    # Get a concatenated path to the unique path designed by the
    # combination of prefix and a unique identificator generated by
    # employing the UUID v4 format. If unique param is set to false
    # than the path will be set to prefix without the unique part.
    envPath: (basis, prefix, unique=uuid.v4()) ->
        assert dirs = nconf.get("env:dirs") or []
        unknown = "Env dir #{basis} is not managed"
        assert _.isString(prefix), "invalid prefix"
        throw new Error unknown unless basis in dirs
        prefix = prefix + "-" + unique if unique
        return paths.join(basis, prefix).toString()
