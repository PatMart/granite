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
assert = require "assert"
asciify = require "asciify"
connect = require "connect"
request = require "request"
logger = require "winston"
colors = require "colors"
async = require "async"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"

{Barebones} = require "../membrane/skeleton"
{Healthcare} = require "../membrane/health"

# This service exposes the entiry hierarchical structure of the
# service documentation, as they scanned and found in the current
# kernel instance. It exposes the data in a structured hierarchy
# encoded with JSON. Please refer to the implementation for info.
# In addition to the documentation it also exposes a complement
# set of service related data, such as health status and so on.
module.exports.Publish = class Publish extends Barebones

    # These invocations establish the parameters which are going
    # to be used for matching HTTP requests against this service.
    # Typically an HTTP pathname pattern and a domain name pattern.
    # Try not to put constraints on the domain, unless necessary.
    # Also, the compounds for the composition system belong here.
    @resource "/api/publish"

    # Establish a heartbeat monitor. A hearbit monitor is a method
    # that tests whether some arbitrarty server functonality does
    # what it is supposed to be. The heartbeats are all executed and
    # kept on the server. A service may define any number of beats.
    # The hearbeat implementation cycle is never exposed to clients.
    @heartbeat "yields a consistent structure", (check, accept) ->
        request.get @qualified(), (error, response, body) =>
            mirror = (obj) => obj.location is @location()
            method = (obj) => obj.method.toString() is "GET"
            check.try "broken body", -> body = JSON.parse body
            check.for "wrong code", response.statusCode is 200
            check.for "wrong body", body and _.isArray body
            check.for "no service", id = _.find body, mirror
            check.for "no GET", get = _.find id.methods, method
            check.not "missing outputs", _.isEmpty get.outputs
            check.not "missing version", _.isEmpty get.version
            check.not "missing synopsis", _.isEmpty get.synopsis
            check.for "no healthcare", _.isObject id.healthcare
            check.for "no relevants", get.relevant.length is 2
            check.for "no markings", get.markings.framework?
            check.for "no githubs", get.github.length is 1
            return accept()

    # A hook that will be called prior to invoking the API method
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    preprocess: (request, response, resource, domain, next) ->
        descriptions = @collectDescriptions()
        internalError = "unexpected publishing error"
        assert _.isObject request.records = descriptions
        return next() unless _.isObject request.platform
        getters = _.map descriptions, (record) => (callback) =>
            conforms = -> record.service.objectOf Healthcare
            return callback() unless (try conforms()) is yes
            assert _.isFunction record.service?.healthcare
            record.service.healthcare (error, measures) ->
                assert.ifError error, internalError
                assert record.healthcare = measures
                return callback undefined
        return async.parallel getters, next

    # Get the contents of the resources at the established path. It
    # is a good idea for this HTTP method to be idempotent. As the
    # rule, this method does not have to alter any contents or data
    # of the resource. Use for unobtrusive retrieval of resources.
    GET: (request, response) ->
        @push response, _.map request.records, (record) ->
            constructor = record.service.constructor
            healthcare: record.healthcare or {}
            qualified: record.service.qualified()
            location: record.service.location()
            identify: constructor.identify()
            patterns: _.map constructor.resources, "source"
            methods: _.map record.methods, (document, method) ->
                relevant: document.relevant()
                markings: document.markings()
                argument: document.argument()
                synopsis: document.synopsis()
                produces: document.produces()
                consumes: document.consumes()
                version: document.version()
                failure: document.failure()
                outputs: document.outputs()
                schemas: document.schemas()
                inputs: document.inputs()
                github: document.github()
                notes: document.notes()
                method: method

    # This block describes certain method of abrbitrary service. The
    # exact process of how it is being documented depends on how the
    # documented function is implemented. Please refer to `Document`
    # class and its module implementation for more information on it.
    @GET (method, service, kernel) ->
        @relevant "ts33kr.github.io/granite/exposure/publish.html"
        @relevant "ts33kr.github.io/granite/membrane/document.html"
        @github "ts33kr", "granite", "library/exposure/publish.coffee"
        @synopsis "Get inventory of all APIs available in the system"
        @outputs "An array of objects, each describes a service"
        @markings framework: "critical", stable: "positive"
        @version kernel.package.version or undefined
        @produces "application/json"