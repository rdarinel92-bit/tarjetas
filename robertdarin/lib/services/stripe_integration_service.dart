/// ═══════════════════════════════════════════════════════════════════════════════
/// SERVICIO: Stripe Integration Service
/// Robert Darin Fintech V10.6
/// ═══════════════════════════════════════════════════════════════════════════════
/// Maneja la integración híbrida: Efectivo + Stripe
/// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/supabase_client.dart';
import '../data/models/stripe_config_model.dart';

class StripeIntegrationService {
  static final StripeIntegrationService _instance = StripeIntegrationService._internal();
  factory StripeIntegrationService() => _instance;
  StripeIntegrationService._internal();
  
  static const String _stripeBaseUrl = 'https://api.stripe.com/v1';

  /// Verificar si Stripe está configurado para un negocio
  Future<bool> isStripeConfigured(String negocioId) async {
    try {
      final res = await AppSupabase.client
          .from('stripe_config')
          .select('id')
          .eq('negocio_id', negocioId)
          .maybeSingle();
      return res != null;
    } catch (e) {
      debugPrint('Error verificando config Stripe: $e');
      return false;
    }
  }

  /// Obtener configuración de Stripe para un negocio
  Future<StripeConfigModel?> getStripeConfig(String negocioId) async {
    try {
      final res = await AppSupabase.client
          .from('stripe_config')
          .select()
          .eq('negocio_id', negocioId)
          .maybeSingle();
      if (res == null) return null;
      return StripeConfigModel.fromMap(res);
    } catch (e) {
      debugPrint('Error obteniendo config Stripe: $e');
      return null;
    }
  }

  /// Guardar/Actualizar configuración de Stripe
  Future<bool> saveStripeConfig(StripeConfigModel config) async {
    try {
      await AppSupabase.client
          .from('stripe_config')
          .upsert(config.toMap());
      return true;
    } catch (e) {
      debugPrint('Error guardando config Stripe: $e');
      return false;
    }
  }

  /// Verificar si un cliente tiene Stripe vinculado
  Future<bool> clienteConStripe(String clienteId) async {
    try {
      final res = await AppSupabase.client
          .from('clientes')
          .select('stripe_customer_id, prefiere_efectivo')
          .eq('id', clienteId)
          .maybeSingle();
      
      if (res == null) return false;
      return res['stripe_customer_id'] != null && res['prefiere_efectivo'] == false;
    } catch (e) {
      debugPrint('Error verificando cliente Stripe: $e');
      return false;
    }
  }

  /// Vincular cliente con Stripe (crear customer en Stripe)
  Future<String?> vincularClienteStripe({
    required String clienteId,
    required String email,
    required String nombre,
    String? telefono,
  }) async {
    try {
      final cliente = await AppSupabase.client
          .from('clientes')
          .select('negocio_id')
          .eq('id', clienteId)
          .maybeSingle();
      if (cliente == null) return null;

      final negocioId = cliente['negocio_id'] as String?;
      if (negocioId == null) return null;

      final config = await getStripeConfig(negocioId);
      final secretKey = config?.stripeSecretKey;
      if (secretKey == null || secretKey.isEmpty) return null;

      final response = await http.post(
        Uri.parse('$_stripeBaseUrl/customers'),
        headers: {
          'Authorization': 'Bearer $secretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'email': email,
          'name': nombre,
          if (telefono != null) 'phone': telefono,
          'metadata[cliente_id]': clienteId,
          'metadata[negocio_id]': negocioId,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final customerId = data['id'] as String?;
        if (customerId == null) return null;

        await AppSupabase.client
            .from('clientes')
            .update({
              'stripe_customer_id': customerId,
              'prefiere_efectivo': false,
            })
            .eq('id', clienteId);

        return customerId;
      }
      return null;
    } catch (e) {
      debugPrint('Error vinculando cliente a Stripe: $e');
      return null;
    }
  }

  /// Marcar cliente como "prefiere efectivo"
  Future<bool> marcarPrefiereEfectivo(String clienteId, bool prefiereEfectivo) async {
    try {
      await AppSupabase.client
          .from('clientes')
          .update({'prefiere_efectivo': prefiereEfectivo})
          .eq('id', clienteId);
      return true;
    } catch (e) {
      debugPrint('Error actualizando preferencia: $e');
      return false;
    }
  }

  /// Crear link de pago para enviar por WhatsApp
  Future<LinkPagoModel?> crearLinkPago({
    required String negocioId,
    required String clienteId,
    required String concepto,
    required double monto,
    String? prestamoId,
    String? tandaId,
    String? amortizacionId,
    String? creadoPor,
    int diasExpiracion = 7,
  }) async {
    try {
      final fechaExpiracion = DateTime.now().add(Duration(days: diasExpiracion));
      
      // Crear el link en la base de datos
      final res = await AppSupabase.client
          .from('links_pago')
          .insert({
            'negocio_id': negocioId,
            'cliente_id': clienteId,
            'prestamo_id': prestamoId,
            'tanda_id': tandaId,
            'amortizacion_id': amortizacionId,
            'concepto': concepto,
            'monto': monto,
            'estado': 'pendiente',
            'fecha_expiracion': fechaExpiracion.toIso8601String(),
            'creado_por': creadoPor,
          })
          .select()
          .single();
      
      // Obtener configuración de Stripe para este negocio
      final config = await getStripeConfig(negocioId);
      if (config != null && config.stripeSecretKey != null && config.stripeSecretKey!.isNotEmpty) {
        try {
          // Crear Payment Link en Stripe
          final stripeResponse = await http.post(
            Uri.parse('$_stripeBaseUrl/payment_links'),
            headers: {
              'Authorization': 'Bearer ${config.stripeSecretKey}',
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {
              'line_items[0][price_data][currency]': 'mxn',
              'line_items[0][price_data][product_data][name]': concepto,
              'line_items[0][price_data][unit_amount]': (monto * 100).toInt().toString(), // Stripe usa centavos
              'line_items[0][quantity]': '1',
              'after_completion[type]': 'redirect',
              'after_completion[redirect][url]': 'https://robertdarin.app/pago-exitoso?link_id=${res['id']}',
              'metadata[link_id]': res['id'],
              'metadata[cliente_id]': clienteId,
              'metadata[negocio_id]': negocioId,
            },
          );
          
          if (stripeResponse.statusCode == 200) {
            final stripeData = jsonDecode(stripeResponse.body);
            final stripeUrl = stripeData['url'];
            final stripeLinkId = stripeData['id'];

            // Actualizar el link con los datos de Stripe
            var actualizado = false;
            try {
              await AppSupabase.client
                  .from('links_pago')
                  .update({
                    'stripe_payment_link_id': stripeLinkId,
                    'stripe_url': stripeUrl,
                  })
                  .eq('id', res['id']);
              actualizado = true;
            } catch (_) {}

            if (!actualizado) {
              try {
                await AppSupabase.client
                    .from('links_pago')
                    .update({
                      'stripe_payment_link_id': stripeLinkId,
                      'url_corta': stripeUrl,
                    })
                    .eq('id', res['id']);
              } catch (updateError) {
                debugPrint('Error actualizando link de pago: $updateError');
              }
            }

            res['stripe_payment_link_id'] = stripeLinkId;
            res['stripe_url'] = stripeUrl;
            res['url_corta'] = stripeUrl;
          } else {
            debugPrint('Error Stripe Payment Link: ${stripeResponse.body}');
          }
        } catch (stripeError) {
          debugPrint('Error conectando con Stripe: $stripeError');
          // El link local ya está creado, solo no tiene URL de Stripe
        }
      }
      
      return LinkPagoModel.fromMap(res);
    } catch (e) {
      debugPrint('Error creando link de pago: $e');
      return null;
    }
  }

  /// Obtener links de pago pendientes de un cliente
  Future<List<LinkPagoModel>> getLinksPendientes(String clienteId) async {
    try {
      final res = await AppSupabase.client
          .from('links_pago')
          .select()
          .eq('cliente_id', clienteId)
          .eq('estado', 'pendiente')
          .order('created_at', ascending: false);
      
      return (res as List).map((e) => LinkPagoModel.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error obteniendo links pendientes: $e');
      return [];
    }
  }

  /// Registrar pago (funciona para efectivo y Stripe)
  Future<bool> registrarPago({
    required String negocioId,
    required String clienteId,
    required double monto,
    required String metodoPago, // efectivo, tarjeta_stripe, link_pago, etc.
    String? prestamoId,
    String? tandaId,
    String? amortizacionId,
    String? nota,
    String? stripePaymentId,
    String? stripeChargeId,
    String? registradoPor,
    double? latitud,
    double? longitud,
  }) async {
    try {
      await AppSupabase.client.from('pagos').insert({
        'negocio_id': negocioId,
        'cliente_id': clienteId,
        'prestamo_id': prestamoId,
        'tanda_id': tandaId,
        'amortizacion_id': amortizacionId,
        'monto': monto,
        'metodo_pago': metodoPago,
        'nota': nota,
        'stripe_payment_id': stripePaymentId,
        'stripe_charge_id': stripeChargeId,
        'cobrado_automatico': metodoPago == 'domiciliacion',
        'registrado_por': registradoPor,
        'latitud': latitud,
        'longitud': longitud,
      });

      // Si tiene amortización, actualizar estado
      if (amortizacionId != null) {
        await AppSupabase.client
            .from('amortizaciones')
            .update({'estado': 'pagado', 'fecha_pago': DateTime.now().toIso8601String()})
            .eq('id', amortizacionId);
      }

      return true;
    } catch (e) {
      debugPrint('Error registrando pago: $e');
      return false;
    }
  }

  /// Obtener resumen de cobros por método
  Future<Map<String, double>> getResumenCobrosPorMetodo(String negocioId, {int meses = 1}) async {
    try {
      final fechaInicio = DateTime.now().subtract(Duration(days: meses * 30));
      
      final res = await AppSupabase.client
          .from('pagos')
          .select('metodo_pago, monto')
          .eq('negocio_id', negocioId)
          .gte('fecha_pago', fechaInicio.toIso8601String());
      
      final resumen = <String, double>{
        'efectivo': 0,
        'transferencia': 0,
        'tarjeta_stripe': 0,
        'link_pago': 0,
        'domiciliacion': 0,
        'total': 0,
      };
      
      for (var pago in res) {
        final metodo = pago['metodo_pago'] ?? 'efectivo';
        final monto = (pago['monto'] as num?)?.toDouble() ?? 0;
        resumen[metodo] = (resumen[metodo] ?? 0) + monto;
        resumen['total'] = (resumen['total'] ?? 0) + monto;
      }
      
      return resumen;
    } catch (e) {
      debugPrint('Error obteniendo resumen: $e');
      return {};
    }
  }

  /// Activar domiciliación para un préstamo
  Future<bool> activarDomiciliacion({
    required String prestamoId,
    required String clienteId,
    required int diaCobro,
    required String negocioId,
    required double montoMensual,
  }) async {
    try {
      // Verificar que el cliente tenga Stripe
      final tieneStripe = await clienteConStripe(clienteId);
      if (!tieneStripe) {
        debugPrint('Cliente no tiene Stripe vinculado');
        return false;
      }
      
      // Obtener stripe_customer_id del cliente
      final clienteRes = await AppSupabase.client
          .from('clientes')
          .select('stripe_customer_id')
          .eq('id', clienteId)
          .single();
      
      final stripeCustomerId = clienteRes['stripe_customer_id'];
      if (stripeCustomerId == null) {
        debugPrint('Cliente no tiene stripe_customer_id');
        return false;
      }
      
      // Obtener configuración de Stripe
      final config = await getStripeConfig(negocioId);
      if (config == null || config.stripeSecretKey == null) {
        debugPrint('No hay configuración de Stripe');
        return false;
      }
      
      String? subscriptionId;
      
      try {
        // Crear producto en Stripe para este préstamo
        final productResponse = await http.post(
          Uri.parse('$_stripeBaseUrl/products'),
          headers: {
            'Authorization': 'Bearer ${config.stripeSecretKey}',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            'name': 'Pago mensual préstamo $prestamoId',
            'metadata[prestamo_id]': prestamoId,
          },
        );
        
        if (productResponse.statusCode != 200) {
          debugPrint('Error creando producto Stripe: ${productResponse.body}');
          return false;
        }
        
        final productData = jsonDecode(productResponse.body);
        
        // Crear precio recurrente
        final priceResponse = await http.post(
          Uri.parse('$_stripeBaseUrl/prices'),
          headers: {
            'Authorization': 'Bearer ${config.stripeSecretKey}',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            'product': productData['id'],
            'unit_amount': (montoMensual * 100).toInt().toString(),
            'currency': 'mxn',
            'recurring[interval]': 'month',
          },
        );
        
        if (priceResponse.statusCode != 200) {
          debugPrint('Error creando precio Stripe: ${priceResponse.body}');
          return false;
        }
        
        final priceData = jsonDecode(priceResponse.body);
        
        // Crear suscripción
        final subscriptionResponse = await http.post(
          Uri.parse('$_stripeBaseUrl/subscriptions'),
          headers: {
            'Authorization': 'Bearer ${config.stripeSecretKey}',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            'customer': stripeCustomerId,
            'items[0][price]': priceData['id'],
            'metadata[prestamo_id]': prestamoId,
            'metadata[negocio_id]': negocioId,
            'billing_cycle_anchor': _calcularProximaFechaCobro(diaCobro).millisecondsSinceEpoch ~/ 1000,
          },
        );
        
        if (subscriptionResponse.statusCode == 200) {
          final subData = jsonDecode(subscriptionResponse.body);
          subscriptionId = subData['id'];
        } else {
          debugPrint('Error creando suscripción Stripe: ${subscriptionResponse.body}');
        }
      } catch (stripeError) {
        debugPrint('Error conectando con Stripe: $stripeError');
      }

      // Actualizar préstamo local
      await AppSupabase.client
          .from('prestamos')
          .update({
            'domiciliacion_activa': true,
            'dia_cobro_automatico': diaCobro,
            'stripe_subscription_id': subscriptionId,
          })
          .eq('id', prestamoId);

      return true;
    } catch (e) {
      debugPrint('Error activando domiciliación: $e');
      return false;
    }
  }
  
  /// Calcular próxima fecha de cobro basada en el día del mes
  DateTime _calcularProximaFechaCobro(int diaCobro) {
    final now = DateTime.now();
    var fecha = DateTime(now.year, now.month, diaCobro);
    if (fecha.isBefore(now)) {
      fecha = DateTime(now.year, now.month + 1, diaCobro);
    }
    return fecha;
  }

  /// Desactivar domiciliación
  Future<bool> desactivarDomiciliacion(String prestamoId, String negocioId) async {
    try {
      // Obtener el subscription_id del préstamo
      final prestamoRes = await AppSupabase.client
          .from('prestamos')
          .select('stripe_subscription_id')
          .eq('id', prestamoId)
          .single();
      
      final subscriptionId = prestamoRes['stripe_subscription_id'];
      
      if (subscriptionId != null) {
        // Obtener configuración de Stripe
        final config = await getStripeConfig(negocioId);
        if (config != null && config.stripeSecretKey != null) {
          try {
            // Cancelar suscripción en Stripe
            final response = await http.delete(
              Uri.parse('$_stripeBaseUrl/subscriptions/$subscriptionId'),
              headers: {
                'Authorization': 'Bearer ${config.stripeSecretKey}',
              },
            );
            
            if (response.statusCode != 200) {
              debugPrint('Error cancelando suscripción Stripe: ${response.body}');
            }
          } catch (stripeError) {
            debugPrint('Error conectando con Stripe para cancelar: $stripeError');
          }
        }
      }

      await AppSupabase.client
          .from('prestamos')
          .update({
            'domiciliacion_activa': false,
            'stripe_subscription_id': null,
          })
          .eq('id', prestamoId);

      return true;
    } catch (e) {
      debugPrint('Error desactivando domiciliación: $e');
      return false;
    }
  }

  /// Log de transacción Stripe (para webhook)
  Future<void> logTransaccionStripe({
    required String negocioId,
    required String stripeEventId,
    required String tipoEvento,
    String? stripePaymentIntentId,
    String? stripeChargeId,
    String? stripeCustomerId,
    double? monto,
    double? comisionStripe,
    String? estado,
    String? mensajeError,
    String? clienteId,
    String? pagoId,
    Map<String, dynamic>? webhookPayload,
  }) async {
    try {
      await AppSupabase.client.from('stripe_transactions_log').insert({
        'negocio_id': negocioId,
        'stripe_event_id': stripeEventId,
        'tipo_evento': tipoEvento,
        'stripe_payment_intent_id': stripePaymentIntentId,
        'stripe_charge_id': stripeChargeId,
        'stripe_customer_id': stripeCustomerId,
        'monto': monto,
        'comision_stripe': comisionStripe,
        'monto_neto': monto != null && comisionStripe != null ? monto - comisionStripe : null,
        'estado': estado,
        'mensaje_error': mensajeError,
        'cliente_id': clienteId,
        'pago_id': pagoId,
        'webhook_payload': webhookPayload,
        'procesado': false,
      });
    } catch (e) {
      debugPrint('Error logging transacción Stripe: $e');
    }
  }
}
