# Copyright 2011-2012 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You
# may not use this file except in compliance with the License. A copy of
# the License is located at
#
#     http://aws.amazon.com/apache2.0/
#
# or in the "license" file accompanying this file. This file is
# distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
# ANY KIND, either express or implied. See the License for the specific
# language governing permissions and limitations under the License.

helpers = require('../helpers')
AWS = helpers.AWS
MockClient = helpers.MockClient

describe 'AWS.Client', ->

  config = null; client = null
  retryableError = (error, result) ->
    expect(client.retryableError(error)).toEqual(result)

  beforeEach ->
    config = new AWS.Config()
    client = new AWS.Client(config)

  describe 'constructor', ->
    it 'should use AWS.config copy if no config is provided', ->
      client = new AWS.Client()
      expect(client.config).not.toBe(AWS.config)
      expect(client.config.sslEnabled).toEqual(true)

    it 'should merge custom options on top of global defaults if config provided', ->
      client = new AWS.Client(maxRetries: 5)
      expect(client.config.sslEnabled).toEqual(true)
      expect(client.config.maxRetries).toEqual(5)

    it 'should allow AWS.config to be object literal', ->
      cfg = AWS.config
      AWS.config = maxRetries: 20
      client = new AWS.Client({})
      expect(client.config.maxRetries).toEqual(20)
      expect(client.config.sslEnabled).toEqual(true)
      AWS.config = cfg

  describe 'makeRequest', ->
    it 'should allow extra config applied per request', ->
      client = new MockClient(maxRetries: 10, sslEnabled: false)
      request = client.makeRequest('foo', {}, {sslEnabled: true, maxRetries: 0})

      expect(request.awsResponse.client.config.sslEnabled).toEqual(true)
      expect(request.awsResponse.client.config.maxRetries).toEqual(0)
      expect(request.awsResponse.client).not.toBe(client)
      expect(client.config.sslEnabled).toEqual(false)
      expect(client.config.maxRetries).toEqual(10)

  describe 'retryableError', ->

    it 'should retry on throttle error', ->
      retryableError({code: 'ProvisionedThroughputExceededException', statusCode:400}, true)

    it 'should retry on expired credentials error', ->
      retryableError({code: 'ExpiredTokenException', statusCode:400}, true)

    it 'should retry on 500 or above regardless of error', ->
      retryableError({code: 'Error', statusCode:500 }, true)
      retryableError({code: 'RandomError', statusCode:505 }, true)

    it 'should not retry when error is < 500 level status code', ->
      retryableError({code: 'Error', statusCode:200 }, false)
      retryableError({code: 'Error', statusCode:302 }, false)
      retryableError({code: 'Error', statusCode:404 }, false)

  describe 'numRetries', ->
    it 'should use config max retry value if defined', ->
      client.config.maxRetries = 30
      expect(client.numRetries()).toEqual(30)

    it 'should use defaultRetries defined on object if undefined on config', ->
      client.defaultRetryCount = 13
      client.config.maxRetries = undefined;
      expect(client.numRetries()).toEqual(13)
