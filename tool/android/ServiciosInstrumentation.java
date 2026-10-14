package com.bto.exploraec.s08lab;

import android.app.Activity;
import android.app.Application;
import android.app.Instrumentation;
import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;

import java.util.Arrays;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

import org.json.JSONObject;

import io.flutter.FlutterInjector;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.dart.DartExecutor;
import io.flutter.embedding.engine.loader.FlutterLoader;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/** Un motor sin Activity, un proceso por fase y resultados exclusivamente booleanos. */
public final class ServiciosInstrumentation extends Instrumentation {
    private static final String PACKAGE = "com.bto.exploraec.s08lab";
    private static final String[] COMMON = {
        "memoria_inicial_vacia", "usuario_inicial_nulo", "me_validado",
        "usuario_presente", "autenticado", "token_igual_persistido",
        "usuario_id_coincide", "generacion_avanza"
    };
    private static final String[] ERRORS = {
        "error_configuracion", "error_almacen", "error_api",
        "error_timeout", "error_interno"
    };
    private final AtomicBoolean finished = new AtomicBoolean();
    private final AtomicBoolean activityObserved = new AtomicBoolean();
    private final Handler main = new Handler(Looper.getMainLooper());
    private volatile boolean pluginsRegistered;
    private String phase;
    private FlutterEngine engine;
    private MethodChannel channel;
    private Application application;
    private ScheduledExecutorService watchdog;

    private final Application.ActivityLifecycleCallbacks activities =
        new Application.ActivityLifecycleCallbacks() {
            @Override public void onActivityCreated(Activity a, Bundle b) { activityObserved.set(true); }
            @Override public void onActivityStarted(Activity a) { activityObserved.set(true); }
            @Override public void onActivityResumed(Activity a) { activityObserved.set(true); }
            @Override public void onActivityPaused(Activity a) {}
            @Override public void onActivityStopped(Activity a) {}
            @Override public void onActivitySaveInstanceState(Activity a, Bundle b) {}
            @Override public void onActivityDestroyed(Activity a) {}
        };

    @Override public void onCreate(Bundle arguments) {
        super.onCreate(arguments);
        try {
            phase = arguments == null ? null : arguments.getString("fase");
        } catch (RuntimeException ignored) {
            phase = null;
        }
        start();
    }

    @Override public void onStart() {
        super.onStart();
        if (!Arrays.asList("guardar", "restaurar", "cerrar").contains(phase)) {
            fail("error_configuracion");
            return;
        }
        watchdog = Executors.newSingleThreadScheduledExecutor(r -> {
            Thread thread = new Thread(r, "cedia-lab-timeout");
            thread.setDaemon(true);
            return thread;
        });
        // Hilo separado: también finaliza si la inicialización bloquea el main.
        watchdog.schedule(() -> fail("error_timeout"), 90, TimeUnit.SECONDS);
        main.post(() -> {
            if (finished.get()) return;
            try {
                Context context = getTargetContext().getApplicationContext();
                if (!PACKAGE.equals(context.getPackageName()) || Build.VERSION.SDK_INT < 24
                        || (context.getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) == 0) {
                    fail("error_configuracion");
                    return;
                }
                application = (Application) context;
                application.registerActivityLifecycleCallbacks(activities);
                FlutterLoader loader = FlutterInjector.instance().flutterLoader();
                loader.startInitialization(context);
                loader.ensureInitializationComplete(context, null);
                if (finished.get()) return;
                // true => GeneratedPluginRegistrant automático; no registro manual duplicado.
                engine = new FlutterEngine(context, null, true);
                Class<? extends FlutterPlugin> storagePlugin = Class.forName(
                    "com.it_nomads.fluttersecurestorage.FlutterSecureStoragePlugin"
                ).asSubclass(FlutterPlugin.class);
                pluginsRegistered = engine.getPlugins().has(storagePlugin);
                if (!pluginsRegistered) {
                    fail("error_nativo");
                    return;
                }
                channel = new MethodChannel(engine.getDartExecutor().getBinaryMessenger(),
                    "cedia_lab_resultados");
                channel.setMethodCallHandler(this::handle);
                engine.getDartExecutor().executeDartEntrypoint(
                    new DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "main"));
            } catch (Throwable ignored) {
                fail("error_nativo");
            }
        });
    }

    private void handle(MethodCall call, MethodChannel.Result reply) {
        if (finished.get()) {
            reply.success(null);
            return;
        }
        if ("configuracion".equals(call.method)) {
            reply.success(Collections.singletonMap("fase", phase));
        } else if ("resultados".equals(call.method)) {
            Map<String, Boolean> checked = validate(call.arguments);
            reply.success(null);
            // Deja responder al canal antes de destruir el motor.
            main.post(() -> {
                if (checked == null) fail("error_protocolo");
                else complete(checked);
            });
        } else {
            reply.notImplemented();
            fail("error_protocolo");
        }
    }

    private Set<String> checks() {
        Set<String> keys = new LinkedHashSet<>(Arrays.asList(COMMON));
        if ("guardar".equals(phase)) {
            keys.addAll(Arrays.asList("almacen_inicial_vacio", "token_no_vacio", "marcador_guardado"));
        } else {
            keys.add("token_previo_no_vacio");
        }
        if ("cerrar".equals(phase)) {
            keys.addAll(Arrays.asList("jwt_memoria_nulo", "usuario_nulo", "autenticado_falso",
                "secure_token_nulo", "generacion_cierre_avanza"));
        }
        return keys;
    }

    private Map<String, Boolean> validate(Object payload) {
        if (!(payload instanceof Map)) return null;
        Map<?, ?> raw = (Map<?, ?>) payload;
        Set<String> allowed = checks();
        allowed.addAll(Arrays.asList(ERRORS));
        allowed.add("ok");
        if (!raw.keySet().equals(allowed)) return null;
        Map<String, Boolean> result = new LinkedHashMap<>();
        for (String key : allowed) {
            Object value = raw.get(key);
            if (!(value instanceof Boolean)) return null;
            result.put(key, (Boolean) value);
        }
        boolean ok = true;
        for (String key : checks()) ok &= Boolean.TRUE.equals(result.get(key));
        for (String key : ERRORS) ok &= Boolean.FALSE.equals(result.get(key));
        if (ok != Boolean.TRUE.equals(result.get("ok"))) return null;
        return result;
    }

    private void fail(String category) {
        Map<String, Boolean> result = new LinkedHashMap<>();
        for (String key : checks()) result.put(key, false);
        for (String key : ERRORS) result.put(key, false);
        result.put("ok", false);
        result.put(category, true); // Categorías constantes, nunca exception.toString().
        complete(result);
    }

    private void complete(Map<String, Boolean> result) {
        if (!finished.compareAndSet(false, true)) return;
        if (watchdog != null) watchdog.shutdownNow();
        if (application != null && Boolean.TRUE.equals(result.get("ok"))) {
            boolean disco = application.getSharedPreferences("cedia_s8_lab", Context.MODE_PRIVATE).edit().commit();
            result.put("escritura_disco_confirmada", disco);
            result.put("ok", disco);
        }
        if (Looper.myLooper() == Looper.getMainLooper()) {
            if (!dispose()) {
                result.put("ok", false);
                result.put("error_nativo", true);
            }
        } else {
            // En timeout no espera al main; finish termina el proceso instrumentado.
            main.post(this::dispose);
        }
        boolean noActivity = !activityObserved.get();
        result.put("sin_activity", noActivity);
        result.put("plugins_registrados", pluginsRegistered);
        boolean ok = Boolean.TRUE.equals(result.get("ok")) && noActivity && pluginsRegistered;
        result.put("ok", ok);
        Bundle output = new Bundle();
        output.putString("resultados", new JSONObject(result).toString());
        // Convención explícita del arnés: 0 éxito, 1 fallo (am instrument no siempre propaga).
        finish(ok ? 0 : 1, output);
    }

    private boolean dispose() {
        boolean ok = true;
        try {
            if (application != null) application.unregisterActivityLifecycleCallbacks(activities);
            if (channel != null) channel.setMethodCallHandler(null);
        } catch (Throwable ignored) {
            ok = false;
        }
        try {
            if (engine != null) engine.destroy();
        } catch (Throwable ignored) {
            ok = false;
        } finally {
            engine = null;
        }
        // No logout, clear-data ni borrado del Keystore durante dispose.
        return ok;
    }

    @Override public boolean onException(Object object, Throwable exception) {
        fail("error_nativo");
        return true;
    }
}
