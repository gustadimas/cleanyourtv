package com.gathin.tvhome;

import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.os.SystemClock;
import android.text.TextUtils;
import android.util.DisplayMetrics;
import android.util.Log;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.animation.DecelerateInterpolator;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.TextView;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Random;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Displays and rotates a theme's local wallpaper images while Home is visible. */
final class WallpaperPlayer {
    private final FrameLayout root;
    private final ImageView image;
    private final int backgroundColor;
    private final List<File> files;
    private final long interval;
    private final String order;
    private final SharedPreferences preferences;
    private final ExecutorService decoder = Executors.newSingleThreadExecutor();
    private final Random random = new Random();
    private final int width;
    /** config wallpaper_true_color: ARGB_8888 instead of RGB_565. */
    private final Bitmap.Config bitmapConfig;
    private final int height;
    /** wallpaper_dim as an ARGB black, painted into each picture once instead of a full-screen shade view. */
    private final int dimColor;
    /** The picture on screen, released once the next one has been drawn. */
    private Bitmap current;
    private boolean active;
    private boolean closed;
    private boolean loading;
    private String displayed = "";
    /** wallpaper_captions: the shown picture's name from wallpapers/captions.txt; null when off or there are none. */
    private final TextView caption;
    private final Map<String, String> names;
    /** wallpaper_moods: the collection's groups by time of day; empty rotates through all of it. */
    private final Map<String, Set<String>> moods;
    /** config.xml latitude and longitude for the sun's times, and today's {sunrise, sunset} once worked out. */
    private final String latitude, longitude;
    private LocalDate sunDay;
    private int[] sun;
    /**
     * focus_wallpapers in the theme's config.json, as "package=slot" (plus "*dock" and "*grid"): every focus on
     * Home shows a random collection picture named "<game>-<slot>.<ext>", from a different game than the one on
     * screen, instead of rotating on a timer. One in twenty picks a "<game>-raro" picture when the theme has one.
     */
    private final Map<String, String> focusSlots = new HashMap<>();
    private final boolean focusMode;
    /** A slot asked for while a decode was running (or before Home was visible); served when it can be. */
    private String focusPending;
    /** With focusPending: the set it has to come from (the idle approach's later stages), or null for any set. */
    private String focusPendingSet;
    /** With focusPending: whether it may turn into the theme's rare picture. */
    private boolean focusPendingRare;
    /**
     * focus_idle_minutes in the theme's config.json: Home left idle shows "<set>-perto1", then "perto2" and "perto3"
     * of the same set, one step per wait (MainActivity times it). 0 when off or the theme has no "perto" pictures.
     */
    private final long approachStepMs;
    /** The set the idle approach is showing, so its later stages stay in the same film. */
    private String approachSet;
    /** focus_effects, focus_sounds: FocusFx draws the changes, the approach and the rare picture's jolt. */
    private FocusFx fx;
    /** focus_mix (on unless false): every focus picks from all the scenes, not only the slot's own pictures. */
    private final boolean mixScenes;
    /**
     * The pictures shown lately, newest first, kept across restarts (preference focus_recent): a picture comes back
     * only after three quarters of the scenes have been shown.
     */
    private final ArrayDeque<String> recent = new ArrayDeque<>();
    private int recentCap = 8;
    /** focus_sets: each set's kind ("assassino", "zumbi"); focus_idle_alerts: each kind's four alert lines. */
    private final Map<String, String> kinds = new HashMap<>();
    private final Map<String, String[]> alerts = new HashMap<>();
    /** focus_days: sets that turn up more often on a day ("F13" for a Friday the 13th, or "MM-DD"). */
    private final Map<String, Set<String>> days = new HashMap<>();
    /** The direction of the move that asked for the next picture (motion), for its push. */
    private int motionX, motionY;
    /** When the last static or flicker ran: never two within 2 s, however fast the focus moves. */
    private long lastEffectAt;

    WallpaperPlayer(Context context, FrameLayout root, Config config) {
        this.root = root;
        backgroundColor = config.backgroundColor;
        files = new ArrayList<>(config.wallpapers);
        JSONObject focusConfig = readFocusConfig(context);
        focusMode = focusConfig != null && readFocusSlots(focusConfig, focusSlots) && !files.isEmpty();
        // Fractions work too (0.25 = 15 s a stage), to try it out.
        double idleMinutes = focusMode && hasSlot("perto1") ? focusConfig.optDouble("focus_idle_minutes", 0) : 0;
        approachStepMs = idleMinutes > 0 ? Math.max(5_000L, Math.round(idleMinutes * 60_000)) : 0;
        mixScenes = focusMode && focusConfig.optBoolean("focus_mix", true);
        boolean effects = focusMode && focusConfig.optBoolean("focus_effects", true);
        boolean withSound = focusMode && focusConfig.optBoolean("focus_sounds", false);
        if (focusMode) readFocusExtras(focusConfig);
        interval = config.wallpaperRotationMinutes * 60_000L;
        bitmapConfig = config.wallpaperTrueColor ? Bitmap.Config.ARGB_8888 : Bitmap.Config.RGB_565;
        // The dim is painted into the picture (decode), so no full-screen shade layer is drawn on every frame.
        dimColor = config.wallpaperDim > 0 ? (config.wallpaperDim * 255 / 100) << 24 : 0;
        order = config.wallpaperOrder;
        preferences = context.getSharedPreferences("wallpaper_rotation", Context.MODE_PRIVATE);
        moods = config.wallpaperMoods;
        latitude = moods.isEmpty() ? "" : context.getString(R.string.latitude);
        longitude = moods.isEmpty() ? "" : context.getString(R.string.longitude);
        // Playback state belongs to one collection. Changing the collection starts from its first
        // picture instead of resuming a filename that belonged to the previous one.
        String collection = collectionKey(files);
        if (!collection.equals(preferences.getString("collection", ""))) {
            preferences.edit().putString("collection", collection)
                    .remove("image").remove("changed").apply();
        }
        DisplayMetrics metrics = context.getResources().getDisplayMetrics();
        width = metrics.widthPixels;
        height = metrics.heightPixels;
        image = new ImageView(context);
        image.setScaleType(ImageView.ScaleType.CENTER_CROP);
        image.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO);
        names = config.wallpaperCaptions && config.wallpaperEnabled && !files.isEmpty()
                ? WallpaperCaptions.read(files.get(0).getParentFile()) : Collections.emptyMap();
        caption = names.isEmpty() ? null : makeCaption(context, root);
        if (config.wallpaperEnabled && !files.isEmpty()) {
            if (focusMode) {
                loadRecent();
                // The picture and the one coming in share a layer, so the approach can move them together.
                FrameLayout layer = new FrameLayout(context);
                layer.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS);
                layer.addView(image, new FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
                root.addView(layer, 0, new FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
                fx = new FocusFx(context, root, layer, image, effects, withSound, random);
            } else {
                root.addView(image, 0, new FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
            }
            showFirst();
        }
    }

    /**
     * The picture Home opens with is decoded right here, on the main thread, as the single wallpaper always was:
     * Home's first frame already has it instead of drawing the plain colour and the picture popping in later.
     * Only the later changes of a rotation decode in the background.
     */
    private void showFirst() {
        String previous = preferences.getString("image", "");
        List<File> playable = playable();
        File first = WallpaperRotation.find(playable, previous);
        if (first == null) first = WallpaperRotation.pick(playable, previous, order, random);
        while (first != null) {
            Bitmap bitmap = decode(first);
            if (bitmap != null) {
                show(bitmap);
                // The picture covers the whole screen: the root's plain colour under it is overdraw.
                root.setBackground(null);
                displayed = first.getName();
                showCaption(false);
                if (!displayed.equals(previous)) {
                    preferences.edit().putString("image", displayed)
                            .putLong("changed", System.currentTimeMillis()).apply();
                }
                return;
            }
            files.remove(first);   // unreadable or over 4K: try another, or keep the plain colour
            playable = playable();
            first = WallpaperRotation.pick(playable, previous, order, random);
        }
    }

    void start() {
        active = true;
        if (focusMode && focusPending != null) {
            String pending = focusPending, pendingSet = focusPendingSet;
            boolean pendingRare = focusPendingRare;
            focusPending = null;
            focusPendingSet = null;
            showSlot(pending, pendingSet, pendingRare);
            return;
        }
        update();
    }

    void stop() {
        active = false;
    }

    /** Drops the wallpaper texture when Home is hidden and Android asks the process to free memory. */
    void releaseForMemoryPressure() {
        if (fx != null) fx.settle();
        if (current == null) return;
        image.setImageDrawable(null);
        // The renderer may still have a queued frame that references this hardware bitmap. Drop our references and
        // let Android reclaim its native buffer after rendering releases it instead of recycling it mid-frame.
        current = null;
        displayed = "";
        root.setBackgroundColor(backgroundColor);
    }

    /** The pictures the rotation picks from now: wallpaper_moods' group for the time of day, or the whole collection. */
    private List<File> playable() {
        List<File> all = focusMode ? calm(files) : files;
        if (moods.isEmpty()) return all;
        LocalDateTime now = LocalDateTime.now();
        if (!now.toLocalDate().equals(sunDay)) {
            sunDay = now.toLocalDate();
            sun = WallpaperMood.sun(sunDay, latitude, longitude, ZoneId.systemDefault());
        }
        return WallpaperMood.select(all, moods, WallpaperMood.timeOfDay(now.getHour() * 60 + now.getMinute(), sun[0], sun[1]));
    }

    /** focus_wallpapers: what a plain rotation (the first picture, an empty screen) may show: no "perto" or "raro". */
    private static List<File> calm(List<File> all) {
        List<File> out = new ArrayList<>();
        for (File file : all) {
            String slot = slotOf(file.getName());
            if (!slot.startsWith("perto") && !slot.equals("raro")) out.add(file);
        }
        return out.isEmpty() ? all : out;
    }

    void close() {
        active = false;
        closed = true;
        if (fx != null) fx.release();
        decoder.shutdownNow();
    }

    void update() {
        if (!active || closed || loading || files.isEmpty()) return;
        // focus_wallpapers: the pictures follow the focus; the timer only fills an empty screen.
        if (focusMode && !displayed.isEmpty()) return;
        String previous = preferences.getString("image", "");
        // A picture outside the time of day's group (the group changed) is replaced at once, not after the interval.
        List<File> playable = playable();
        File selected = WallpaperRotation.find(playable, previous);
        long changed = preferences.getLong("changed", 0);
        if (selected == null || WallpaperRotation.due(changed, System.currentTimeMillis(), interval)) {
            selected = WallpaperRotation.pick(playable, previous, order, random);
        }
        if (selected == null || selected.getName().equals(displayed)) return;
        File next = selected;
        loading = true;
        decoder.execute(() -> {
            Bitmap bitmap = decode(next);
            root.post(() -> {
                loading = false;
                if (closed || !active) {
                    if (bitmap != null) bitmap.recycle();
                    return;
                }
                if (bitmap == null) {
                    files.remove(next);
                    Log.w("TvHome.Wallpaper", "Skipping unreadable image: " + next.getName());
                    update();
                    return;
                }
                show(bitmap);
                displayed = next.getName();
                showCaption(true);
                if (!displayed.equals(previous) || changed == 0) {
                    preferences.edit().putString("image", displayed)
                            .putLong("changed", System.currentTimeMillis()).apply();
                }
            });
        });
    }

    /** A focused tile: a dock app's own slot, or the "*dock" / "*grid" slot for the rest. */
    void focus(String pkg, boolean dock) {
        if (!focusMode) return;
        String slot = dock && pkg != null ? focusSlots.get(pkg) : null;
        if (slot == null) slot = focusSlots.get(dock ? "*dock" : "*grid");
        if (slot != null) focusSlot(slot);
    }

    /** Shows a random "<game>-<slot>" picture, cross-fading from the current one. */
    void focusSlot(String slot) {
        showSlot(slot, null, true);
    }

    /** The wait before each stage of the idle approach; 0 when the theme has none. */
    long approachStepMs() {
        return approachStepMs;
    }

    /**
     * Home left idle: stage 1 shows the film on screen coming ("perto1"; another film when it has none), stages 2 and
     * 3 bring it closer ("perto2", "perto3"), each with FocusFx's overlays and an alert line. Stage 0 sends it away
     * with the kind's last line; MainActivity then asks again for the focused item's picture.
     */
    void approach(int stage) {
        if (!focusMode) return;
        if (stage <= 0) {
            if (approachSet != null && fx != null) {
                fx.approach(0);
                fx.alert(alertLine(approachSet, 3, null), false, 1_800);
            }
            approachSet = null;
            return;
        }
        String now = gameOf(displayed);
        String set = stage > 1 ? approachSet : hasPicture(now, "perto1") ? now : null;
        Log.i("TvHome.Approach", "stage " + stage + (set == null ? "" : " of " + set));
        showSlot("perto" + Math.min(stage, 3), set, false);
    }

    /** The direction of the move that asks for the next picture: -1, 0 or 1 across and down. */
    void motion(int dx, int dy) {
        motionX = Integer.signum(dx);
        motionY = Integer.signum(dy);
    }

    /** A random picture for the slot, from the given set or (null) from any set but the one on screen. */
    private void showSlot(String slot, String set, boolean mayBeRare) {
        if (!focusMode || closed) return;
        if (!active || loading) {
            focusPending = slot;
            focusPendingSet = set;
            focusPendingRare = mayBeRare;
            return;
        }
        String wanted = mayBeRare && random.nextInt(20) == 0 && hasSlot("raro") ? "raro" : slot;
        File next = pick(wanted, set);
        if (next == null) return;
        remember(next.getName());
        if (wanted.startsWith("perto")) approachSet = gameOf(next.getName());
        int style = styleFor(wanted);
        int dx = motionX, dy = motionY;
        motionX = 0;
        motionY = 0;
        loading = true;
        decoder.execute(() -> {
            Bitmap bitmap = decode(next);
            root.post(() -> {
                loading = false;
                if (closed) {
                    if (bitmap != null) bitmap.recycle();
                    return;
                }
                if (bitmap != null && active) {
                    present(bitmap, style, dx, dy);
                    displayed = next.getName();
                    showCaption(true);
                    afterShow(wanted, displayed);
                } else if (bitmap != null) {
                    bitmap.recycle();
                }
                // A request that came in meanwhile; while Home is hidden it waits for start().
                if (active && focusPending != null) {
                    String pending = focusPending, pendingSet = focusPendingSet;
                    boolean pendingRare = focusPendingRare;
                    focusPending = null;
                    focusPendingSet = null;
                    showSlot(pending, pendingSet, pendingRare);
                }
            });
        });
    }

    private void crossfade(Bitmap bitmap) {
        image.animate().cancel();
        image.animate().alpha(0.25f).setDuration(110).withEndAction(() -> {
            show(bitmap);
            image.animate().alpha(1f).setDuration(280).start();
        }).start();
    }

    /** Puts a focus picture on screen through FocusFx (the plain dip without it); the old one goes once hidden. */
    private void present(Bitmap bitmap, int style, int dx, int dy) {
        if (fx == null) {
            crossfade(bitmap);
            return;
        }
        Bitmap old = current;
        current = bitmap;
        root.setBackground(null);
        fx.swap(bitmap, style, dx, dy, () -> {
            if (old != null && old != bitmap && old != current) image.postDelayed(old::recycle, 500);
        });
    }

    /** How a change looks: the approach's stages and the rare picture have their own; the rest mostly push. */
    private int styleFor(String wanted) {
        long now = SystemClock.uptimeMillis();
        int style;
        if (wanted.equals("perto1")) {
            style = FocusFx.SLOW;
        } else if (wanted.equals("perto2") || wanted.equals("raro")) {
            style = FocusFx.STATIC;
        } else if (wanted.equals("perto3")) {
            style = FocusFx.FLICKER;
        } else if (now - lastEffectAt < 2_000) {
            style = FocusFx.PUSH;   // moving fast: no static or flicker twice within 2 s
        } else {
            int roll = random.nextInt(10);
            style = roll < 7 ? FocusFx.PUSH : roll < 9 ? FocusFx.STATIC : FocusFx.FLICKER;
        }
        if (style == FocusFx.STATIC || style == FocusFx.FLICKER) lastEffectAt = now;
        return style;
    }

    /** What goes with the picture just shown: the approach's overlays and alert line, or the rare picture's jolt. */
    private void afterShow(String wanted, String name) {
        if (fx == null) return;
        if (wanted.startsWith("perto")) {
            int stage = Math.max(1, Math.min(3, wanted.charAt(wanted.length() - 1) - '0'));
            fx.approach(stage);
            fx.alert(alertLine(gameOf(name), stage - 1, name), stage >= 3, stage >= 3 ? 6_000 : 4_500);
        } else if (wanted.equals("raro")) {
            fx.rare();
        }
    }

    /** focus_idle_alerts' line for the set's kind; without one, the picture's caption (none for the last line). */
    private String alertLine(String set, int index, String name) {
        String kind = kinds.get(set);
        String[] lines = kind == null ? null : alerts.get(kind);
        if (lines != null && index >= 0 && index < lines.length && !lines[index].trim().isEmpty()) {
            return lines[index].trim();
        }
        return index >= 3 || name == null ? null : names.get(name);
    }

    private boolean hasSlot(String slot) {
        for (File file : files) if (slotOf(file.getName()).equals(slot)) return true;
        return false;
    }

    /**
     * The next picture. A scene (focus_mix) is any picture that is not an approach stage or the rare one; otherwise
     * the slot's own. It comes from the given set, or from a film other than the one on screen and, when possible,
     * none of the last four; never one shown lately (focus_recent); and on focus_days, more often today's sets.
     */
    private File pick(String wanted, String set) {
        boolean scene = mixScenes && !special(wanted);
        String now = gameOf(displayed);
        List<File> pool = new ArrayList<>();
        List<File> sameFilm = new ArrayList<>();
        for (File file : files) {
            String name = file.getName(), slot = slotOf(name);
            if (name.equals(displayed) || (scene ? special(slot) : !slot.equals(wanted))) continue;
            String film = gameOf(name);
            if (set != null) {
                if (film.equals(set)) pool.add(file);
            } else if (film.equals(now)) {
                sameFilm.add(file);
            } else {
                pool.add(file);
            }
        }
        if (pool.isEmpty()) pool = sameFilm;
        if (pool.isEmpty()) return null;
        Set<String> lastFilms = new HashSet<>();
        int seen = 0;
        for (String name : recent) {
            if (seen++ >= 4) break;
            lastFilms.add(gameOf(name));
        }
        List<File> fresh = new ArrayList<>();
        List<File> freshest = new ArrayList<>();
        for (File file : pool) {
            if (recent.contains(file.getName())) continue;
            fresh.add(file);
            if (!lastFilms.contains(gameOf(file.getName()))) freshest.add(file);
        }
        List<File> from = !freshest.isEmpty() ? freshest : !fresh.isEmpty() ? fresh : pool;
        Set<String> today = set == null ? todaysSets() : Collections.<String>emptySet();
        if (!today.isEmpty() && random.nextInt(10) < 4) {
            List<File> favored = new ArrayList<>();
            for (File file : from) if (today.contains(gameOf(file.getName()))) favored.add(file);
            if (favored.isEmpty()) for (File file : pool) if (today.contains(gameOf(file.getName()))) favored.add(file);
            if (!favored.isEmpty()) from = favored;
        }
        return from.get(random.nextInt(from.size()));
    }

    /** The approach's stages and the rare picture: never picked as a plain scene. */
    private static boolean special(String slot) {
        return slot.startsWith("perto") || slot.equals("raro");
    }

    private boolean hasPicture(String set, String slot) {
        if (set.isEmpty()) return false;
        for (File file : files) {
            String name = file.getName();
            if (gameOf(name).equals(set) && slotOf(name).equals(slot)) return true;
        }
        return false;
    }

    /** focus_recent: up to three quarters of the scenes, newest first. */
    private void loadRecent() {
        int scenes = 0;
        for (File file : files) if (!special(slotOf(file.getName()))) scenes++;
        recentCap = Math.max(8, scenes * 3 / 4);
        for (String name : preferences.getString("focus_recent", "").split("\n")) {
            if (!name.isEmpty() && recent.size() < recentCap) recent.addLast(name);
        }
    }

    private void remember(String name) {
        recent.remove(name);
        recent.addFirst(name);
        while (recent.size() > recentCap) recent.removeLast();
        preferences.edit().putString("focus_recent", TextUtils.join("\n", recent)).apply();
    }

    /** focus_days' sets for today: a Friday the 13th ("F13") and this month-day ("10-31"). */
    private Set<String> todaysSets() {
        if (days.isEmpty()) return Collections.emptySet();
        LocalDate today = LocalDate.now();
        Set<String> out = new HashSet<>();
        Set<String> friday13 = days.get("F13");
        if (friday13 != null && today.getDayOfMonth() == 13 && today.getDayOfWeek() == DayOfWeek.FRIDAY) {
            out.addAll(friday13);
        }
        Set<String> date = days.get(String.format(Locale.ROOT, "%02d-%02d", today.getMonthValue(), today.getDayOfMonth()));
        if (date != null) out.addAll(date);
        return out;
    }

    /** focus_sets, focus_idle_alerts and focus_days: lists of "key=value" lines, like focus_wallpapers. */
    private void readFocusExtras(JSONObject json) {
        JSONArray sets = json.optJSONArray("focus_sets");
        for (int i = 0; sets != null && i < sets.length(); i++) {
            String entry = sets.optString(i, "");
            int eq = entry.indexOf('=');
            if (eq <= 0) continue;
            String kind = entry.substring(0, eq).trim();
            for (String set : entry.substring(eq + 1).split(",")) {
                if (!set.trim().isEmpty()) kinds.put(set.trim(), kind);
            }
        }
        JSONArray lines = json.optJSONArray("focus_idle_alerts");
        for (int i = 0; lines != null && i < lines.length(); i++) {
            String entry = lines.optString(i, "");
            int eq = entry.indexOf('=');
            if (eq > 0) alerts.put(entry.substring(0, eq).trim(), entry.substring(eq + 1).split("\\|", -1));
        }
        JSONArray dayList = json.optJSONArray("focus_days");
        for (int i = 0; dayList != null && i < dayList.length(); i++) {
            String entry = dayList.optString(i, "");
            int eq = entry.indexOf('=');
            if (eq <= 0) continue;
            String day = entry.substring(0, eq).trim();
            Set<String> into = days.get(day);
            if (into == null) {
                into = new HashSet<>();
                days.put(day, into);
            }
            for (String set : entry.substring(eq + 1).split(",")) {
                if (!set.trim().isEmpty()) into.add(set.trim());
            }
        }
    }

    /** "twd-youtube.jpg" -> "twd". */
    private static String gameOf(String name) {
        int dash = name.indexOf('-');
        return dash > 0 ? name.substring(0, dash) : "";
    }

    /** "twd-youtube.jpg" -> "youtube". */
    private static String slotOf(String name) {
        int dash = name.lastIndexOf('-'), dot = name.lastIndexOf('.');
        return dash >= 0 && dot > dash ? name.substring(dash + 1, dot) : "";
    }

    /** The theme's config.json (or the launcher's own copy of it) when it has focus_wallpapers; null otherwise. */
    private static JSONObject readFocusConfig(Context context) {
        File[] candidates = {new File(Config.dir(context), Config.FILE_NAME), new File(context.getFilesDir(), Config.FILE_NAME)};
        for (File file : candidates) {
            if (file == null || !file.isFile() || file.length() > 64 * 1024) continue;
            try (InputStream in = new FileInputStream(file)) {
                byte[] buf = new byte[(int) file.length()];
                int n = 0, r;
                while (n < buf.length && (r = in.read(buf, n, buf.length - n)) > 0) n += r;
                JSONObject json = new JSONObject(new String(buf, 0, n, StandardCharsets.UTF_8));
                return json.has("focus_wallpapers") ? json : null;
            } catch (Exception e) {
                Log.w("TvHome.Wallpaper", "focus_wallpapers unreadable: " + e.getMessage());
                return null;
            }
        }
        return null;
    }

    /** focus_wallpapers' "package=slot" entries; false when there are none. */
    private static boolean readFocusSlots(JSONObject json, Map<String, String> into) {
        JSONArray list = json.optJSONArray("focus_wallpapers");
        if (list == null) return false;
        for (int i = 0; i < list.length(); i++) {
            String entry = list.optString(i, "");
            int eq = entry.indexOf('=');
            if (eq > 0 && eq < entry.length() - 1) into.put(entry.substring(0, eq).trim(), entry.substring(eq + 1).trim());
        }
        return !into.isEmpty();
    }

    /**
     * Small light text under the top-right buttons, above everything else and never focusable. It sits where the
     * top bar ends in every layout, so it does not cover the clock, the stats line or the tiles.
     */
    private static TextView makeCaption(Context context, FrameLayout root) {
        float dp = context.getResources().getDisplayMetrics().density;
        TextView text = new TextView(context);
        text.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15);
        text.setTextColor(0xD9FFFFFF);
        text.setShadowLayer(6 * dp, 0, dp, 0xCC000000);
        text.setSingleLine(true);
        text.setEllipsize(TextUtils.TruncateAt.END);
        text.setMaxWidth(Math.round(520 * dp));
        text.setFocusable(false);
        text.setAlpha(0f);
        try {
            text.setTypeface(UiFont.get(context, R.string.font_regular));
        } catch (Exception ignored) {
            // the system font is fine
        }
        FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.TOP | Gravity.END);
        params.topMargin = Math.round(110 * dp);
        params.setMarginEnd(Math.round(62 * dp));
        root.addView(text, params);
        return text;
    }

    /** The displayed picture's name, faded across a change; a picture without a name hides the caption. */
    private void showCaption(boolean fade) {
        if (caption == null) return;
        String name = names.get(displayed);
        caption.animate().cancel();
        if (name == null) {
            caption.setAlpha(0f);
            return;
        }
        caption.setContentDescription(name);
        if (!fade || caption.getAlpha() == 0f) {
            caption.setText(name);
            caption.setTranslationY(0f);
            caption.setAlpha(1f);
            return;
        }
        float rise = 8 * caption.getResources().getDisplayMetrics().density;
        caption.animate().alpha(0f).translationY(-rise).setDuration(220).withEndAction(() -> {
            caption.setText(name);
            caption.setTranslationY(rise);
            caption.animate().alpha(1f).translationY(0f).setDuration(420)
                    .setInterpolator(new DecelerateInterpolator()).start();
        }).start();
    }

    /** Names plus sizes: enough to notice a different collection without hashing every image. */
    private static String collectionKey(List<File> images) {
        StringBuilder key = new StringBuilder();
        for (File file : images) key.append(file.getName()).append(':').append(file.length()).append(';');
        return key.toString();
    }

    /** Puts a picture on screen and releases the previous one after a frame has drawn the new one. */
    private void show(Bitmap bitmap) {
        Bitmap old = current;
        current = bitmap;
        // The wallpaper covers the whole root; avoid drawing the fallback colour under it.
        root.setBackground(null);
        image.setImageBitmap(bitmap);
        if (old != null && old != bitmap) image.postDelayed(old::recycle, 500);
    }

    private Bitmap decode(File file) {
        try {
            BitmapFactory.Options options = new BitmapFactory.Options();
            options.inJustDecodeBounds = true;
            BitmapFactory.decodeFile(file.getPath(), options);
            int width = options.outWidth, height = options.outHeight;
            if (width <= 0 || height <= 0) return null;
            int sample = WallpaperSize.sampleSize(width, height, this.width, this.height);
            if (!WallpaperSize.accepted(width / sample, height / sample)) return null;
            options.inJustDecodeBounds = false;
            options.inSampleSize = sample;
            int[] scale = WallpaperSize.coverScale(width / sample, height / sample, this.width, this.height);
            if (scale != null) {
                options.inScaled = true;
                options.inDensity = scale[0];
                options.inTargetDensity = scale[1];
            }
            options.inPreferredConfig = bitmapConfig;
            options.inMutable = dimColor != 0;
            Bitmap decoded = BitmapFactory.decodeFile(file.getPath(), options);
            if (decoded == null) return null;
            if (dimColor != 0) new Canvas(decoded).drawColor(dimColor);
            // One copy in GPU memory instead of a software bitmap plus its texture; the decode stays off the UI
            // thread for rotations, and Home's return no longer uploads 4-8 MB to the GPU.
            Bitmap gpu = decoded.copy(Bitmap.Config.HARDWARE, false);
            if (gpu == null) return decoded;
            decoded.recycle();
            return gpu;
        } catch (Exception | OutOfMemoryError failure) {
            return null;
        }
    }
}
