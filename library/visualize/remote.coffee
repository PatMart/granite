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
asciify = require "asciify"
connect = require "connect"
logger = require "winston"
events = require "events"
colors = require "colors"
nconf = require "nconf"
https = require "https"
paths = require "path"
http = require "http"
util = require "util"
fs = require "fs"

# A shorthand method for creating new instances of the objectables.
# This method is better than explicitly creating new objects, since
# it is shorter and has nicer syntax. Please use this, instead of
# directly creating new objectables. Refer to the later for info.
module.exports.objectable = (@objectable) ->
    detected = _.isFunction @objectable
    passed = -> @objectable.length is 0
    objectable = "The argument is not a function"
    wrapping = "The wrapper must not have arguments"
    throw new Error objectable unless detected
    throw new Error wrapping unless passed()
    return new Objectable @objectable

# A shorthand method for creating new instances of the executables.
# This method is better than explicitly creating new objects, since
# it is shorter and has nicer syntax. Please use this, instead of
# directly creating new executable. Refer to the later for info.
module.exports.executable = (@executable) ->
    detected = _.isFunction @executable
    executable = "The argument is not a function"
    throw new Error executable unless detected
    return new Executable @executable

# A class that represents a wrapped remote classes. It accepts the
# class wrapped in function and then stores it for later. Then when
# requested, it emits the class object source code as a string and if
# requested - optionally emits stringified application construct
# around it. This is used to remote create class objects on the site.
module.exports.Objectable = class Objectable extends events.EventEmitter

    # A public constructor that takes the wrapped class object for
    # an objectible object. Beware, when you are passing the class
    # definitin in here, remember that the definition is most likely
    # will be executed on a remote side, with differen environment.
    constructor: (@objectable) ->

    # Generation of string representation of the object instantiation
    # in JavaScript, so that it can be executed remotely on site. An
    # object instantiation invocation cannot be bound to other than
    # only a set of arguments that must be scalars or similar to them.
    # This method does not do any processing of args, inserts raws.
    unprocessed: (parameters...) ->
        detected = _.isFunction @objectable
        passed = -> @objectable.length is 0
        objectable = "No valid objectable has been set"
        wrapping = "The wrapper must not have arguments"
        throw new Error objectable unless detected
        throw new Error wrapping unless passed()
        joined = parameters.join(", ").toString()
        stringified = @objectable.toString()
        "new ((#{stringified})()) (#{joined})"

    # Generation of string representation of the object instantiation
    # in JavaScript, so that it can be executed remotely on site. An
    # object instantiation invocation cannot be bound to other than
    # only a set of arguments that must be scalars or similar to them.
    # This method does process the args, each arg being inspected.
    processed: (parameters...) ->
        detected = _.isFunction @objectable
        passed = -> @objectable.length is 0
        objectable = "No valid objectable has been set"
        wrapping = "The wrapper must not have arguments"
        throw new Error objectable unless detected
        throw new Error wrapping unless passed()
        inspected = _.map parameters, util.inspect
        joined = inspected.join(", ").toString()
        stringified = @objectable.toString()
        "new ((#{stringified})()) (#{joined})"

# A class that represents a wrapped remote function. It accept the
# native, normal function and then stores it for later. Then when
# requested, it emits the function source code as a string and if
# requested - optionally emits stringified application construct
# around it. This is used to remote execute functions on the site.
module.exports.Executable = class Executable extends events.EventEmitter

    # A public constructor that takes the executable for a function
    # object. Beware, this must be a singular, simple function, not
    # a constructor, not a bound method. It must not have any sort
    # of dependencies, because it will executed in different place.
    constructor: (@executable) ->

    # Generation of string representation of the function invocation
    # in JavaScript, so that it can be executed remotely on site. An
    # invocation may be bound to an arbitrary remote this variable
    # and a set of arguments that must be scalars or similar to them.
    # This method does not do any processing of args, inserts raws.
    unprocessed: (binder, parameters...) ->
        detected = _.isFunction @executable
        executable = "No valid executable has been set"
        throw new Error executable unless detected
        parameters.unshift binder or "this"
        joined = parameters.join(", ").toString()
        stringified = @executable.toString()
        "(#{stringified}).apply(#{joined})"

    # Generation of string representation of the function invocation
    # in JavaScript, so that it can be executed remotely on site. An
    # invocation may be bound to an arbitrary remote this variable
    # and a set of arguments that must be scalars or similar to them.
    # This method does process the args, each arg being inspected.
    processed: (binder, parameters...) ->
        detected = _.isFunction @executable
        executable = "No valid executable has been set"
        throw new Error executable unless detected
        inspected = _.map parameters, util.inspect
        joined = inspected.join(", ").toString()
        stringified = @executable.toString()
        inspected.unshift binder or "this"
        "(#{stringified}).apply(#{joined})"
