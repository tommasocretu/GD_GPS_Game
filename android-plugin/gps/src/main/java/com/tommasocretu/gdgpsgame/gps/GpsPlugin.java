package com.tommasocretu.gdgpsgame.gps;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageManager;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.location.LocationRequest;
import android.os.Build;
import android.os.Bundle;
import android.os.Looper;
import android.os.SystemClock;
import android.view.View;

import org.godotengine.godot.Dictionary;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;

/**
 * Minimal Android v2 plugin: platform LocationManager -> Godot signal.
 *
 * Threading rule: the LocationListener runs on the Android main thread, so it
 * only builds a Dictionary and calls emitSignal(), which Godot marshals onto
 * the render thread. No GDScript call is made directly from the listener.
 */
public class GpsPlugin extends GodotPlugin implements LocationListener {
    private static final String PLUGIN_NAME = "GpsPlugin";
    private static final String FINE = Manifest.permission.ACCESS_FINE_LOCATION;
    private static final String COARSE = Manifest.permission.ACCESS_COARSE_LOCATION;

    private final SignalInfo fixSignal = new SignalInfo("location_fix", Dictionary.class);
    private final SignalInfo errorSignal = new SignalInfo("location_error", String.class);

    private LocationManager manager;
    private Dictionary lastFix = new Dictionary();
    private String activeProvider;

    public GpsPlugin(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return PLUGIN_NAME;
    }

    @Override
    public Set<SignalInfo> getPluginSignals() {
        return new HashSet<>(Arrays.asList(fixSignal, errorSignal));
    }

    @Override
    public View onMainCreate(Activity activity) {
        if (activity != null) {
            manager = (LocationManager) activity.getSystemService(Context.LOCATION_SERVICE);
        }
        return super.onMainCreate(activity);
    }

    @Override
    public void onMainPause() {
        stop_updates();
    }

    private boolean hasFinePermission() {
        Activity activity = getActivity();
        return activity != null
            && activity.checkSelfPermission(FINE) == PackageManager.PERMISSION_GRANTED;
    }

    private boolean hasCoarsePermission() {
        Activity activity = getActivity();
        return activity != null
            && activity.checkSelfPermission(COARSE) == PackageManager.PERMISSION_GRANTED;
    }

    private static boolean isProviderEnabled(LocationManager m, String provider) {
        try {
            return m.isProviderEnabled(provider);
        } catch (Exception ignored) {
            return false;
        }
    }

    private String chooseProvider(LocationManager m) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
            && isProviderEnabled(m, LocationManager.FUSED_PROVIDER)) {
            return LocationManager.FUSED_PROVIDER;
        }
        if (isProviderEnabled(m, LocationManager.GPS_PROVIDER)) {
            return LocationManager.GPS_PROVIDER;
        }
        if (isProviderEnabled(m, LocationManager.NETWORK_PROVIDER)) {
            return LocationManager.NETWORK_PROVIDER;
        }
        return null;
    }

    @UsedByGodot
    public boolean start_updates(int intervalMs, int minIntervalMs, float minDistanceM) {
        Activity activity = getActivity();
        if (activity == null || manager == null) {
            emitSignal(errorSignal, "no_provider");
            return false;
        }
        if (!hasFinePermission()) {
            emitSignal(errorSignal, hasCoarsePermission() ? "coarse_only" : "missing_permission");
            return false;
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && !manager.isLocationEnabled()) {
            emitSignal(errorSignal, "location_disabled");
            return false;
        }

        String provider = chooseProvider(manager);
        if (provider == null) {
            emitSignal(errorSignal, "no_provider");
            return false;
        }

        try {
            stop_updates();
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                Api31.start(manager, provider, intervalMs, minIntervalMs, minDistanceM, activity, this);
            } else {
                manager.requestLocationUpdates(
                    provider,
                    intervalMs,
                    minDistanceM,
                    this,
                    Looper.getMainLooper()
                );
            }
            activeProvider = provider;
            return true;
        } catch (SecurityException e) {
            emitSignal(errorSignal, "missing_permission");
            return false;
        } catch (Exception e) {
            emitSignal(errorSignal, "start_failed");
            return false;
        }
    }

    /** Kept in a nested class so API 26 devices never resolve LocationRequest. */
    @android.annotation.TargetApi(Build.VERSION_CODES.S)
    private static final class Api31 {
        static void start(LocationManager manager, String provider, int intervalMs,
                          int minIntervalMs, float minDistanceM, Activity activity,
                          LocationListener listener) {
            LocationRequest request = new LocationRequest.Builder(intervalMs)
                .setQuality(LocationRequest.QUALITY_HIGH_ACCURACY)
                .setMinUpdateIntervalMillis(minIntervalMs)
                .setMinUpdateDistanceMeters(minDistanceM)
                .build();
            manager.requestLocationUpdates(provider, request, activity.getMainExecutor(), listener);
        }
    }

    @UsedByGodot
    public void stop_updates() {
        if (manager != null) {
            try {
                manager.removeUpdates(this);
            } catch (Exception ignored) {
                // Provider may have disappeared while the app was paused.
            }
        }
        activeProvider = null;
    }

    @UsedByGodot
    public Dictionary get_last_fix() {
        return lastFix;
    }

    @UsedByGodot
    public String get_active_provider() {
        return activeProvider == null ? "" : activeProvider;
    }

    @Override
    public void onLocationChanged(Location location) {
        Dictionary data = new Dictionary();
        data.put("latitude", location.getLatitude());
        data.put("longitude", location.getLongitude());
        data.put("accuracy", (double) location.getAccuracy());
        data.put("altitude", location.getAltitude());
        data.put("speed", location.hasSpeed() ? (double) location.getSpeed() : -1.0);
        data.put("bearing", location.hasBearing() ? (double) location.getBearing() : -1.0);
        data.put("time_ms", location.getTime());
        data.put("elapsed_ns", location.getElapsedRealtimeNanos());
        long ageMs = (SystemClock.elapsedRealtimeNanos() - location.getElapsedRealtimeNanos()) / 1_000_000L;
        data.put("age_ms", (double) Math.max(0L, ageMs));
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            data.put("is_mock", location.isMock());
        } else {
            data.put("is_mock", location.isFromMockProvider());
        }
        lastFix = data;
        emitSignal(fixSignal, data);
    }

    @Override
    public void onStatusChanged(String provider, int status, Bundle extras) {
        // Required for API 26-29 compatibility.
    }

    @Override
    public void onProviderEnabled(String provider) {
    }

    @Override
    public void onProviderDisabled(String provider) {
        emitSignal(errorSignal, "provider_disabled:" + provider);
    }
}
