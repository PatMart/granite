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
asciify = require "asciify"
connect = require "connect"
assert = require "assert"
logger = require "winston"
events = require "eventemitter2"
colors = require "colors"
async = require "async"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"
url = require "url"

{Document} = require "./document"
{Service} = require "../nucleus/service"

# This is an abstract service compount that provides the essential
# capabilities of keeping track of service health. This abstract base
# class provides instruments to define criterias to estimate whether
# a service is healthy or not. On top of that it exposes the system
# that allows to query the health care status for all the services.
module.exports.Healthcare = class Healthcare extends Service

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # This method wraps a vanilla supplied heartbeat estimate with
    # a special wrapper. This wrapper provides a smater callback to
    # the estimate as compared to the default one in `async`. Please
    # refer to the implementation for the information on a callback.
    # Implementation directly affects the contents of the result map.
    @heartrate: (bound) -> (callback) =>
        internalError = "heartbeat internal error"
        wrongWiring = "received no valid callback"
        assert _.isFunction(bound), internalError
        assert _.isFunction(callback), wrongWiring
        assert guardian = require("domain").create()
        accept = -> callback undefined, success: yes
        guard = (heartbeat) -> guardian.run heartbeat
        check = Object.create events.EventEmitter2::
        check.not = (m, c) -> throw new Error m if c
        check.for = (m, c) -> throw new Error m unless c
        check.try = (m, f) -> try f() catch e then @not m, e
        guardian.on "error", (e) => @healthreport e, callback
        guard -> bound check, accept, (m) -> check.for m

    # An internal complementary part of the healthcare system. It is
    # used to create an appropriate healthcare report when heartbeat
    # fails gracefully to ensure the health status. This method does
    # include information such as originating file and line number.
    # Please refer to the implementation regarding extracted info.
    @healthreport: (error, callback) ->
        assert descriptor = new Object success: no
        generic = "the health status has been rejected"
        noFrame = "no correct stack trace frame is found"
        pattern = /\s+at\s(.+)\s\((.+):(\d+):(\d+),.+\)/g
        descriptor.message = error.message or generic
        assert frames = pattern.collect error.stack
        select = -> frames[2] or frames[1] or undefined
        assert not _.isEmpty(target = select()), noFrame
        assert not _.isEmpty descriptor.file = target[2]
        assert not _.isEmpty descriptor.line = target[3]
        assert not _.isEmpty descriptor.cols = target[4]
        return try callback undefined, descriptor

    # Run a healthcare check on the service instance. This method
    # retrieves all the heartbeats of this service and its hierarchy
    # run them in parallel, asynchronously. Once done, a callback
    # will be invoked with the result object where key corresponds
    # to a summary and a value to a success or failure. Also, if any
    # error happens in any of the hertbeats, it reports to callback.
    healthcare: (callback) ->
        adapt = (f) => return @constructor.heartrate f
        bind = (method) => return adapt method.bind this
        heartbeats = @constructor.heartbeat() or Array()
        assert indexed = _.indexBy heartbeats, "summary"
        assert id = try @constructor.identify().underline
        transform = (a, v, k) -> a[k] = bind v.estimate
        transformed = _.transform indexed, transform
        message = "healthcare error at %s service: %s"
        async.parallel transformed, (error, map) ->
            return callback null, map unless error
            logger.debug message.red, id, error
            callback.call this, error; this

    # Define a new heartbeat monitor in the service hierarchy. It
    # consists of a heartbeat descriptor and an estimation function
    # that is actually invoked to determine if a service is healthy
    # or not. If any of the classes in the inheritance hierarchy
    # defines any heartbeats, those will be inherited down a chain.
    # If an estimate throws an exception the hearbeat is a failure.
    @heartbeat: (summary, estimate) ->
        noSummary = "no heartbeat summary given"
        noEstimate = "received no estimate function"
        wrongArgs = "should accept at least 1 argument"
        return @$heartbeat if arguments.length is 0
        assert not _.isEmpty(summary), noSummary
        assert _.isFunction(estimate), noEstimate
        assert estimate.length >= 1, wrongArgs
        @$heartbeat = (@$heartbeat or []).concat
            summary: summary.toString()
            estimate: estimate
