import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:provider/provider.dart';
import '../../../../core/00_base/module_base.dart';
import '../../../../core/managers/module_manager.dart';
import '../../../../core/managers/services_manager.dart';
import '../../../../core/services/shared_preferences.dart';
import '../../../../tools/logging/logger.dart';
import '../../../../core/managers/state_manager.dart';
import '../connections_api_module/connections_api_module.dart';
import '../../../../utils/consts/config.dart';
import '../login_module/login_module.dart';

import 'components/socket_connection_manager.dart';
import 'components/room_manager.dart';
import 'components/session_manager.dart';
import 'components/token_manager.dart';
import 'components/event_handler.dart';
import 'components/result_handler.dart';
import 'components/broadcast_manager.dart';
import 'components/message_manager.dart';
import 'components/websocket_state.dart';

class WebSocketModule extends ModuleBase {
  static final Logger _log = Logger();
  late ModuleManager _moduleManager;
  late ServicesManager _servicesManager;
  StateManager? _stateManager;
  SharedPrefManager? _sharedPref;
  ConnectionsApiModule? _connectionModule;
  BuildContext? _currentContext;
  bool _mounted = true;

  // Components
  late SocketConnectionManager _socketManager;
  late RoomManager _roomManager;
  late SessionManager _sessionManager;
  late TokenManager _tokenManager;
  late EventHandler _eventHandler;
  late ResultHandler _resultHandler;
  late BroadcastManager _broadcastManager;
  late MessageManager _messageManager;

  // Getter for socket
  IO.Socket? get socket => _socketManager.socket;

  WebSocketModule() : super("websocket_module") {
    _log.info('✅ WebSocketModule initialized.');
    
    // Initialize components with default values
    _socketManager = SocketConnectionManager(_setupEventHandlers);
    _roomManager = RoomManager(_socketManager.socket);
    _sessionManager = SessionManager();
    _tokenManager = TokenManager(null); // Will be updated in _initDependencies
    _eventHandler = EventHandler();
    _resultHandler = ResultHandler();
    _broadcastManager = BroadcastManager();
    _messageManager = MessageManager(_roomManager, _socketManager);
  }

  @override
  void initialize(BuildContext context) {
    _initDependencies(context);
    _log.info('✅ WebSocketModule initialized with context.');
  }

  void _initDependencies(BuildContext context) {
    try {
      _moduleManager = Provider.of<ModuleManager>(context, listen: false);
      _servicesManager = Provider.of<ServicesManager>(context, listen: false);
      _stateManager = Provider.of<StateManager>(context, listen: false);
      _sharedPref = _servicesManager.getService<SharedPrefManager>('shared_pref');
      _connectionModule = _moduleManager.getLatestModule<ConnectionsApiModule>();
      _currentContext = context;

      if (_stateManager == null) {
        _log.error("❌ StateManager not available");
        return;
      }

      // Pass StateManager to EventHandler
      _eventHandler.setStateManager(_stateManager!);

      // Initialize state in StateManager
      _stateManager!.registerPluginState("websocket", <String, dynamic>{
        "isConnected": false,
        "sessionId": null,
        "userId": null,
        "username": null,
        "currentRoomId": null,
        "roomState": null,
        "joinedRooms": [],
        "sessionData": null,
        "lastActivity": null,
        "connectionTime": null,
        "error": null,
        "isLoading": false,
        "hasValidToken": false
      });

      // Update TokenManager with the connection module
      _tokenManager = TokenManager(_connectionModule);
      _tokenManager.setStateManager(_stateManager!);
    } catch (e) {
      _log.error("❌ Error initializing dependencies: $e");
    }
  }

  void _setupEventHandlers(IO.Socket socket) {
    _roomManager.setSocket(socket);
    _eventHandler.setSocket(socket);
    _broadcastManager.setSocket(socket);
    _eventHandler.setupEventHandlers();
  }

  Future<bool> connect(BuildContext context) async {
    if (!_mounted) {
      _log.error('❌ WebSocketModule is not mounted');
      return false;
    }

    try {
      // Initialize dependencies if not already done
      if (_stateManager == null) {
        _initDependencies(context);
      }

      if (_stateManager == null) {
        _log.error("❌ StateManager not available after initialization");
        return false;
      }

      // Update loading state
      _stateManager!.updatePluginState("websocket", <String, dynamic>{"isLoading": true});

      // Get fresh token
      _log.info("🔑 Getting valid token for WebSocket connection...");
      String? accessToken = await _tokenManager.getValidToken();
      if (accessToken == null) {
        _stateManager!.updatePluginState("websocket", <String, dynamic>{
          "isLoading": false,
          "error": "No valid access token available"
        });
        return false;
      }
      _log.info("✅ Got valid token for WebSocket connection");

      // Connect to WebSocket server
      final success = await _socketManager.connect(accessToken);
      if (!success) {
        _stateManager!.updatePluginState("websocket", <String, dynamic>{
          "isLoading": false,
          "error": "Connection failed"
        });
        return false;
      }

      // Wait for session ID to be available
      int attempts = 0;
      while (_socketManager.socket?.id == null && attempts < 10) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      if (_socketManager.socket?.id == null) {
        _log.error("❌ Failed to get session ID after connection");
        await disconnect();
        _stateManager!.updatePluginState("websocket", <String, dynamic>{
          "isLoading": false,
          "error": "Failed to get session ID"
        });
        return false;
      }

      // Get user info from login module
      final loginModule = _moduleManager.getLatestModule<LoginModule>();
      if (loginModule != null) {
        final userStatus = await loginModule.getUserStatus(context);
        if (userStatus["status"] == "logged_in" && userStatus["user_id"] != null) {
          _sessionManager.setUserId(userStatus["user_id"].toString());
          _sessionManager.setUsername(userStatus["username"]?.toString());
          
          // Update both websocket and game room states
          _stateManager!.updatePluginState("websocket", <String, dynamic>{
            "userId": userStatus["user_id"].toString(),
            "username": userStatus["username"]?.toString(),
            "sessionData": userStatus,
            "lastActivity": DateTime.now().toIso8601String(),
            "connectionTime": DateTime.now().toIso8601String(),
          });

          // Also update game room state if it exists
          final gameRoomState = _stateManager!.getPluginState<Map<String, dynamic>>("game_room");
          if (gameRoomState != null) {
            _stateManager!.updatePluginState("game_room", <String, dynamic>{
              ...gameRoomState,
              "userId": userStatus["user_id"].toString(),
              "isConnected": true,
            });
          }
        }
      }

      // Start token refresh timer
      _tokenManager.startTokenRefreshTimer();
      
      // Update state with successful connection
      _stateManager!.updatePluginState("websocket", <String, dynamic>{
        "isLoading": false,
        "error": null,
        "sessionId": _socketManager.socket?.id,
        "isConnected": true
      });
      
      return true;
    } catch (e) {
      _log.error('❌ Error connecting to WebSocket: $e');
      if (_stateManager != null) {
        _stateManager!.updatePluginState("websocket", <String, dynamic>{
          "isLoading": false,
          "error": e.toString()
        });
      }
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      // Stop token refresh timer
      _tokenManager.dispose();
      
      // Leave current room if any
      if (_roomManager.currentRoomId != null) {
        await _roomManager.leaveRoom(_roomManager.currentRoomId!);
      }
      
      // Disconnect socket
      await _socketManager.disconnect();
      
      // Clear state
      _sessionManager.clearSessionData();
      _roomManager.clearRooms();
      _currentContext = null;
      
      // Update state if available
      if (_stateManager != null) {
        // Update websocket state
        _stateManager!.updatePluginState("websocket", <String, dynamic>{
          "isConnected": false,
          "sessionId": null,
          "currentRoomId": null,
          "roomState": null,
          "joinedRooms": [],
          "error": null
        });

        // Also update game room state if it exists
        final gameRoomState = _stateManager!.getPluginState<Map<String, dynamic>>("game_room");
        if (gameRoomState != null) {
          _stateManager!.updatePluginState("game_room", <String, dynamic>{
            ...gameRoomState,
            "isConnected": false,
            "roomId": null,
            "roomState": null,
            "error": null
          });
        }
      }
      
      _log.info("✅ WebSocket disconnected and cleaned up");
    } catch (e) {
      _log.error("❌ Error during disconnect: $e");
      if (_stateManager != null) {
        _stateManager!.updatePluginState("websocket", <String, dynamic>{
          "error": e.toString()
        });
      }
    }
  }

  Future<WebSocketResult> joinRoom(String roomId) async {
    return _roomManager.joinRoom(roomId);
  }

  Future<WebSocketResult> joinGame(String roomId) async {
    return _roomManager.joinRoom(roomId);
  }

  Future<WebSocketResult> leaveRoom(String roomId) async {
    return _roomManager.leaveRoom(roomId);
  }

  Future<WebSocketResult> createRoom(String userId) async {
    return _messageManager.createRoom(userId);
  }

  Future<WebSocketResult> sendMessage(String message) async {
    return _messageManager.sendMessage(message);
  }

  Future<WebSocketResult> pressButton() async {
    return _messageManager.pressButton();
  }

  Future<WebSocketResult> getCounter() async {
    return _messageManager.getCounter();
  }

  Future<WebSocketResult> getUsers() async {
    return _messageManager.getUsers();
  }

  String? getCurrentRoomId() {
    return _roomManager.currentRoomId;
  }

  Map<String, dynamic>? getSessionData() {
    return _sessionManager.sessionData;
  }

  String? getUserId() {
    return _sessionManager.getUserId();
  }

  String? getUsername() {
    return _sessionManager.getUsername();
  }

  List<String> getRooms() {
    return _sessionManager.getRooms();
  }

  bool isInRoom(String roomId) {
    return _sessionManager.isInRoom(roomId);
  }

  Stream<Map<String, dynamic>> get eventStream => _eventHandler.eventStream;

  void registerEventHandler(String event, Function(Map<String, dynamic>) handler) {
    _eventHandler.registerHandler(event, handler);
  }

  @override
  void dispose() {
    _mounted = false;
    disconnect();
    _eventHandler.dispose();
    _tokenManager.dispose();
  }
} 