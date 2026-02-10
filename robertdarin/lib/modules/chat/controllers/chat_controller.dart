import '../../../data/models/chat_conversacion_model.dart';
import '../../../data/models/chat_mensaje_model.dart';
import '../../../data/models/chat_participante_model.dart';
import '../../../data/models/auditoria_legal_model.dart';
import '../../../data/repositories/chat_conversaciones_repository.dart';
import '../../../data/repositories/chat_mensajes_repository.dart';
import '../../../data/repositories/chat_participantes_repository.dart';
import '../../../data/repositories/auditoria_legal_repository.dart';
import '../../../data/services/hash_service.dart';

class ChatController {
  final ChatConversacionesRepository conversacionesRepository;
  final ChatMensajesRepository mensajesRepository;
  final ChatParticipantesRepository participantesRepository;
  final AuditoriaLegalRepository auditoriaLegalRepository;
  final HashService hashService;

  ChatController({
    required this.conversacionesRepository,
    required this.mensajesRepository,
    required this.participantesRepository,
    required this.auditoriaLegalRepository,
    required this.hashService,
  });

  Future<List<ChatConversacionModel>> obtenerConversacionesPorUsuario(String usuarioId) async {
    return await conversacionesRepository.obtenerConversacionesPorUsuario(usuarioId);
  }

  Future<ChatConversacionModel?> obtenerConversacionPorId(String conversacionId) async {
    return await conversacionesRepository.obtenerConversacionPorId(conversacionId);
  }

  Future<ChatConversacionModel> crearConversacionDirecta({
    required String creadoPorUsuarioId,
    required String otroUsuarioId,
    required String rolCreador,
    required String rolOtroUsuario,
  }) async {
    final conversacion = ChatConversacionModel(
      id: '',
      tipoConversacion: 'directo',
      clienteId: null,
      avalId: null,
      prestamoId: null,
      tandaId: null,
      creadoPorUsuarioId: creadoPorUsuarioId,
      estado: 'activa',
      createdAt: DateTime.now(),
    );
    final creada = await conversacionesRepository.crearConversacion(conversacion);
    final participante1 = ChatParticipanteModel(
      id: '',
      conversacionId: creada!.id,
      usuarioId: creadoPorUsuarioId,
      rolEnChat: rolCreador,
      notificacionesActivas: true,
      createdAt: DateTime.now(),
    );
    final participante2 = ChatParticipanteModel(
      id: '',
      conversacionId: creada.id,
      usuarioId: otroUsuarioId,
      rolEnChat: rolOtroUsuario,
      notificacionesActivas: true,
      createdAt: DateTime.now(),
    );
    await participantesRepository.agregarParticipante(participante1);
    await participantesRepository.agregarParticipante(participante2);
    return creada;
  }

  Future<ChatConversacionModel> crearConversacionPorPrestamo({
    required String creadoPorUsuarioId,
    required String clienteId,
    String? avalId,
    required String prestamoId,
  }) async {
    final conversacion = ChatConversacionModel(
      id: '',
      tipoConversacion: 'prestamo',
      clienteId: clienteId,
      avalId: avalId,
      prestamoId: prestamoId,
      tandaId: null,
      creadoPorUsuarioId: creadoPorUsuarioId,
      estado: 'activa',
      createdAt: DateTime.now(),
    );
    final creada = await conversacionesRepository.crearConversacion(conversacion);
    final participante1 = ChatParticipanteModel(
      id: '',
      conversacionId: creada!.id,
      usuarioId: creadoPorUsuarioId,
      rolEnChat: 'operador',
      notificacionesActivas: true,
      createdAt: DateTime.now(),
    );
    final participante2 = ChatParticipanteModel(
      id: '',
      conversacionId: creada.id,
      usuarioId: clienteId,
      rolEnChat: 'cliente',
      notificacionesActivas: true,
      createdAt: DateTime.now(),
    );
    await participantesRepository.agregarParticipante(participante1);
    await participantesRepository.agregarParticipante(participante2);
    if (avalId != null && avalId.isNotEmpty) {
      final participante3 = ChatParticipanteModel(
        id: '',
        conversacionId: creada.id,
        usuarioId: avalId,
        rolEnChat: 'aval',
        notificacionesActivas: true,
        createdAt: DateTime.now(),
      );
      await participantesRepository.agregarParticipante(participante3);
    }
    return creada;
  }

  Future<ChatConversacionModel> crearConversacionPorTanda({
    required String creadoPorUsuarioId,
    required String tandaId,
    required List<String> participantesUsuarioIds,
  }) async {
    final conversacion = ChatConversacionModel(
      id: '',
      tipoConversacion: 'tanda',
      clienteId: null,
      avalId: null,
      prestamoId: null,
      tandaId: tandaId,
      creadoPorUsuarioId: creadoPorUsuarioId,
      estado: 'activa',
      createdAt: DateTime.now(),
    );
    final creada = await conversacionesRepository.crearConversacion(conversacion);
    final participanteOperador = ChatParticipanteModel(
      id: '',
      conversacionId: creada!.id,
      usuarioId: creadoPorUsuarioId,
      rolEnChat: 'operador',
      notificacionesActivas: true,
      createdAt: DateTime.now(),
    );
    await participantesRepository.agregarParticipante(participanteOperador);
    for (final usuarioId in participantesUsuarioIds) {
      final participante = ChatParticipanteModel(
        id: '',
        conversacionId: creada.id,
        usuarioId: usuarioId,
        rolEnChat: 'cliente',
        notificacionesActivas: true,
        createdAt: DateTime.now(),
      );
      await participantesRepository.agregarParticipante(participante);
    }
    return creada;
  }

  Future<List<ChatMensajeModel>> obtenerMensajes(String conversacionId) async {
    return await mensajesRepository.obtenerMensajesPorConversacion(conversacionId);
  }

  Future<ChatMensajeModel?> enviarMensajeTexto({
    required String conversacionId,
    required String remitenteUsuarioId,
    required String contenido,
    bool esSistema = false,
  }) async {
    final hash = hashService.generarHash(contenido);
    final mensaje = ChatMensajeModel(
      id: '',
      conversacionId: conversacionId,
      remitenteUsuarioId: remitenteUsuarioId,
      tipoMensaje: 'texto',
      contenidoTexto: contenido,
      archivoUrl: null,
      latitud: null,
      longitud: null,
      hashContenido: hash,
      esSistema: esSistema,
      createdAt: DateTime.now(),
    );
    final creado = await mensajesRepository.crearMensaje(mensaje);
    if (creado != null) {
      final auditoria = AuditoriaLegalModel(
        id: '',
        tipoEntidad: 'chat_mensaje',
        entidadId: creado.id,
        accion: 'enviar_mensaje',
        usuarioId: remitenteUsuarioId,
        ip: '',
        latitud: null,
        longitud: null,
        dispositivo: '',
        hashContenido: hash,
        createdAt: DateTime.now(),
      );
      await auditoriaLegalRepository.registrarAuditoria(auditoria);
    }
    return creado;
  }

  Future<ChatMensajeModel?> enviarMensajeArchivo({
    required String conversacionId,
    required String remitenteUsuarioId,
    required String archivoUrl,
    String? descripcion,
    bool esSistema = false,
  }) async {
    final hash = hashService.generarHash(archivoUrl + (descripcion ?? ''));
    final mensaje = ChatMensajeModel(
      id: '',
      conversacionId: conversacionId,
      remitenteUsuarioId: remitenteUsuarioId,
      tipoMensaje: 'archivo',
      contenidoTexto: descripcion,
      archivoUrl: archivoUrl,
      latitud: null,
      longitud: null,
      hashContenido: hash,
      esSistema: esSistema,
      createdAt: DateTime.now(),
    );
    final creado = await mensajesRepository.crearMensaje(mensaje);
    if (creado != null) {
      final auditoria = AuditoriaLegalModel(
        id: '',
        tipoEntidad: 'chat_mensaje',
        entidadId: creado.id,
        accion: 'enviar_mensaje',
        usuarioId: remitenteUsuarioId,
        ip: '',
        latitud: null,
        longitud: null,
        dispositivo: '',
        hashContenido: hash,
        createdAt: DateTime.now(),
      );
      await auditoriaLegalRepository.registrarAuditoria(auditoria);
    }
    return creado;
  }

  Future<ChatMensajeModel?> enviarMensajeUbicacion({
    required String conversacionId,
    required String remitenteUsuarioId,
    required double latitud,
    required double longitud,
    bool esSistema = false,
  }) async {
    final hash = hashService.generarHash(' 24latitud, 24longitud');
    final mensaje = ChatMensajeModel(
      id: '',
      conversacionId: conversacionId,
      remitenteUsuarioId: remitenteUsuarioId,
      tipoMensaje: 'ubicacion',
      contenidoTexto: null,
      archivoUrl: null,
      latitud: latitud,
      longitud: longitud,
      hashContenido: hash,
      esSistema: esSistema,
      createdAt: DateTime.now(),
    );
    final creado = await mensajesRepository.crearMensaje(mensaje);
    if (creado != null) {
      final auditoria = AuditoriaLegalModel(
        id: '',
        tipoEntidad: 'chat_mensaje',
        entidadId: creado.id,
        accion: 'enviar_mensaje',
        usuarioId: remitenteUsuarioId,
        ip: '',
        latitud: latitud,
        longitud: longitud,
        dispositivo: '',
        hashContenido: hash,
        createdAt: DateTime.now(),
      );
      await auditoriaLegalRepository.registrarAuditoria(auditoria);
    }
    return creado;
  }
}
