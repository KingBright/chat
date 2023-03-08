// create a chatgpt chat api implementation
// curl format is:
// curl https://api.openai.com/v1/chat/completions \
//   -H 'Content-Type: application/json' \
//   -H 'Authorization: Bearer YOUR_API_KEY' \
//   -d '{
//   "model": "gpt-3.5-turbo",
//   "messages": [{"role": "user", "content": "Hello!"}]
// }'
//
// reply format is:
// {
//   "id": "chatcmpl-123",
//   "object": "chat.completion",
//   "created": 1677652288,
//   "choices": [{
//     "index": 0,
//     "message": {
//       "role": "assistant",
//       "content": "\n\nHello there, how may I assist you today?",
//     },
//     "finish_reason": "stop"
//   }],
//   "usage": {
//     "prompt_tokens": 9,
//     "completion_tokens": 12,
//     "total_tokens": 21
//   }
// }

import 'dart:io';
import 'dart:convert';

// ChatApi class
class ChatApi {
  // constructor with api key, optional proxy and port
  ChatApi(this.apiKey, [this.proxy = '', this.port = 0]);

  // api key
  final String apiKey;

  // api url
  final String apiUrl = 'https://api.openai.com/v1/chat/completions';

  // api body
  final Map<String, dynamic> apiBody = {
    'model': 'gpt-3.5-turbo',
    'messages': [
      {'role': 'user', 'content': 'Hello!'}
    ]
  };

  // proxy support, host and port
  bool useProxy = true;
  final String proxy;
  final int port;

  // HttpClient instance, for reuse
  final HttpClient httpClient = HttpClient();

  // cache CacheMessage with a list, and store the list in a map, use user name as key, the user name should be passed in in the requestMessage function
  final Map<String, List<CacheMessage>> responseCache = {};

  // api request with message, if called from retry, then not cache the message
  Future<ChatResponse> requestWithMessage(
    String message,
    String userName, [
    bool retry = false,
  ]) async {
    // update api body
    apiBody['messages'][0]['content'] = message;

    // http post request, use HttpClient to support proxy
    if (useProxy && proxy.isNotEmpty && port > 0) {
      // log
      print('Using proxy: $proxy:$port');
      httpClient.findProxy = (Uri uri) {
        return 'PROXY $proxy:$port';
      };
    }
    final HttpClientRequest request =
        await httpClient.postUrl(Uri.parse(apiUrl));
    // set headers, content-type and authorization
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Authorization', 'Bearer $apiKey');

    // set body
    request.add(utf8.encode(json.encode(apiBody)));

    // get response
    final HttpClientResponse response = await request.close();

    if (responseCache[userName] == null) {
      responseCache[userName] = [];
    }

    // consider failure
    if (response.statusCode != 200) {
      // add log
      print(
          'Failed to load chat response, status code: ${response.statusCode}');
      // cache message, the chat response should be invalid
      if (!retry) {
        responseCache[userName]!.add(
          CacheMessage(message, null),
        );
      }

      throw Exception('Failed to load chat response');
    }

    // get response and transform to ChatResponse
    final String responseBody = await response.transform(utf8.decoder).join();
    final ChatResponse chatResponse = ChatResponse.fromString(responseBody);

    // add log
    print('Chat response: $responseBody');

    // cache message
    if (!retry) {
      responseCache[userName]!.add(
        CacheMessage(message, chatResponse),
      );
    }

    // return response
    return chatResponse;
  }

  // a function to get the last response
  ChatResponse getLastResponse(String userName) {
    // get the last response
    final CacheMessage lastCacheMessage = responseCache[userName]!.last;

    // if chat reponse is null, throw exception
    if (lastCacheMessage.replyChatResponse == null) {
      throw Exception('No chat response');
    }

    // return the last response
    return lastCacheMessage.replyChatResponse!;
  }

  // retry last message
  Future<ChatResponse> retryLastMessage(String userName) async {
    // get the last message
    final CacheMessage lastCacheMessage = responseCache[userName]!.last;

    // get the last message
    final String lastMessage = lastCacheMessage.inputMessage;

    // request with last message
    final ChatResponse chatResponse =
        await requestWithMessage(lastMessage, userName, true);

    // return response
    return chatResponse;
  }

  // enable or disable proxy in just one funcion
  void setProxyEnable(bool enable) {
    useProxy = enable;
  }
}

// ChatResponse class, init from string not http.Response
class ChatResponse {
  // response json
  late final Map<String, dynamic> responseJson;

  ChatResponse.fromString(response) {
    responseJson = jsonDecode(response);
  }

  // response id
  String get responseId => responseJson['id'];

  // response object
  String get responseObject => responseJson['object'];

  // response created
  int get responseCreated => responseJson['created'];

  // response choices
  List<dynamic> get responseChoices => responseJson['choices'];

  // response usage
  Map<String, dynamic> get responseUsage => responseJson['usage'];

  // response prompt tokens
  int get responsePromptTokens => responseUsage['prompt_tokens'];

  // response completion tokens
  int get responseCompletionTokens => responseUsage['completion_tokens'];

  // response total tokens
  int get responseTotalTokens => responseUsage['total_tokens'];

  // response choice index
  int get responseChoiceIndex => responseChoices[0]['index'];

  // response choice message
  Map<String, dynamic> get responseChoiceMessage =>
      responseChoices[0]['message'];

  // response choice message role
  String get responseChoiceMessageRole => responseChoiceMessage['role'];

  // response choice message content
  String get responseChoiceMessageContent => responseChoiceMessage['content'];

  // response choice finish reason
  String get responseChoiceFinishReason => responseChoices[0]['finish_reason'];

  // simply get the message content
  String get message => responseChoiceMessage['content'];
}

// CacheMessage class to store input message and the reply ChatResponse
class CacheMessage {
  // constructor with input message and reply ChatResponse
  CacheMessage(this.inputMessage, this.replyChatResponse);

  // input message
  final String inputMessage;

  // reply ChatResponse
  ChatResponse? replyChatResponse;
}
