import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livehelp/model/model.dart';
import 'package:livehelp/services/server_repository.dart';

part 'chat_messages_event.dart';
part 'chat_messages_state.dart';

class ChatMessagesBloc extends Bloc<ChatMessagesEvent, ChatMessagesState>{
  final ServerRepository serverRepository;
  ChatMessagesBloc({required this.serverRepository}) : super(ChatMessagesInitial())
  {
    on<FetchChatMessages>(_onFetchChatMessages);
    on<PostMessage>(_onPostMessage);
    on<CloseChat>(_onCloseChat);
    on<DeleteChat>(_onDeleteChat);
  }

  Future<void> _onFetchChatMessages(FetchChatMessages event, Emitter<ChatMessagesState> emit) async{
    {
      final currentState=state;
      try {
        String chatStatus = "";
        int chatStatusCode = 0;
        int? lastMsgId = 0;
        var chatData = {};
        List<Message> msgs = [];

        if(currentState is ChatMessagesLoaded) {
          lastMsgId = currentState.messages.isNotEmpty ? currentState.messages.last.id : 0;
        }

        chatData = await serverRepository.syncMessages(event.server, event.chat, lastMsgId!);
        if (chatData.containsKey('chat_status')) {
          chatStatus = chatData['chat_status'] ?? "";
        }

        if (chatData.containsKey('chat_scode')) {
          chatStatusCode = chatData['chat_scode'] ?? 0;
        }

        if (chatData.containsKey('messages')) {
          msgs.addAll(chatData['messages']);
        }
        if( state is ChatMessagesInitial){
          emit(ChatMessagesLoaded(server:
              event.server,
              chat: event.chat,
              messages: msgs,
              chatStatus: chatStatus,
              chatStatusCode: chatStatusCode));
        }

        if(currentState is ChatMessagesLoaded) {
          emit(currentState.copyWith(server:
          event.server,
              chat: event.chat,
              messages: List.from(currentState.messages)..addAll(msgs),
              chatStatus: chatStatus,
              chatStatusCode: chatStatusCode));
        }

      } on Exception {
        emit(const ChatMessagesLoadError(message: "Chat list could not be loaded"));
      }
    }
  }

  Future<void> _onPostMessage(PostMessage event, Emitter<ChatMessagesState> emit)async {
    final currentState = state;
    print(currentState.toString());
    if (currentState is ChatMessagesLoaded) {
      await serverRepository.postMesssage(event.server, event.chat, event.message!);
      add(FetchChatMessages(server: event.server, chat: event.chat));
    }
  }

  Future<void> _onCloseChat(CloseChat event, Emitter<ChatMessagesState> emit) async{
    final currentState = state;
    var closed = false;
    if (currentState is ChatMessagesLoaded) {
      emit(currentState.copyWith(isLoading: true));
      try{
          closed = await serverRepository.closeChat(
              event.server, event.chat);
        emit(currentState.copyWith(isChatClosed: closed,  isLoading: false));
      } catch(ex){
        emit(currentState.copyWith(isLoading: false));
        emit(ChatMessagesLoadError(message: ex.toString()));
      }
    }
  }

  Future<void> _onDeleteChat(DeleteChat event, Emitter<ChatMessagesState> emit) async{
    final currentState = state;
    var closed = false;
    if (currentState is ChatMessagesLoaded) {
      emit(currentState.copyWith(isLoading: true));
      try{
        closed = await serverRepository.deleteChat(event.server, event.chat);
        emit(currentState.copyWith(isChatClosed: closed,  isLoading: false));
      } catch(ex){
        emit(currentState.copyWith(isLoading: false));
        emit(ChatMessagesLoadError(message: ex.toString()));
      }
    }
  }

}