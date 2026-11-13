package com.gathin.tvhome;

import android.animation.Animator;
import android.animation.AnimatorListenerAdapter;
import android.animation.ObjectAnimator;
import android.animation.ValueAnimator;
import android.content.Context;
import android.content.res.Resources;
import android.graphics.Bitmap;
import android.graphics.Typeface;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.GradientDrawable;
import android.media.AudioAttributes;
import android.media.SoundPool;
import android.util.DisplayMetrics;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.animation.DecelerateInterpolator;
import android.view.animation.LinearInterpolator;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.TextView;

import java.util.Random;

/**
 * focus_wallpapers' look: how one picture gives way to the next (focus_effects), the idle approach's overlays and
 * alert line, and the optional sounds (focus_sounds). Only alpha, translation and scale are animated, each for a
 * moment, so Home goes back to drawing nothing once a change has settled.
 */
final class FocusFx {
    /** Change styles: plain fade, a push from the move's direction, a burst of tape static, a failing bulb, a slow fade. */
    static final int FADE = 0, PUSH = 1, STATIC = 2, FLICKER = 3, SLOW = 4;

    private final FrameLayout layer;
    private final ImageView bottom;
    private final ImageView top;
    private final View noise;
    private final View vignette;
    private final View danger;
    private final TextView alert;
    private final Runnable hideAlert;
    private final BitmapDrawable[] noiseFrames = new BitmapDrawable[3];
    private final Resources resources;
    private final Random random;
    private final float dp;
    private final boolean effects;
    private SoundPool sounds;
    private int soundStatic, soundHeart, soundHit;
    /** The picture coming in, until the change settles, and what to run then. */
    private Bitmap incoming;
    private Runnable incomingDone;
    private ValueAnimator swapAnimator;
    private ObjectAnimator heart;
    /** focus_style_ms: how long a change lasts in real time, 0 for each style's own length. */
    private long styleMs;

    /** layer holds the bottom picture (WallpaperPlayer's) at index 0 of root; everything else goes just above it. */
    FocusFx(Context context, FrameLayout root, FrameLayout layer, ImageView bottom, boolean effects, boolean withSound,
            Random random) {
        this.layer = layer;
        this.bottom = bottom;
        this.effects = effects;
        this.random = random;
        resources = context.getResources();
        DisplayMetrics metrics = resources.getDisplayMetrics();
        dp = metrics.density;
        top = new ImageView(context);
        top.setScaleType(ImageView.ScaleType.CENTER_CROP);
        top.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO);
        top.setVisibility(View.INVISIBLE);
        layer.addView(top, full());
        noise = new View(context);
        noise.setVisibility(View.GONE);
        layer.addView(noise, full());
        float reach = (float) Math.hypot(metrics.widthPixels, metrics.heightPixels) * 0.52f;
        vignette = shade(context, 0xF2000000, reach);
        danger = shade(context, 0xC8900000, reach);
        root.addView(vignette, 1, full());
        root.addView(danger, 2, full());
        alert = new TextView(context);
        alert.setTextSize(TypedValue.COMPLEX_UNIT_SP, 30);
        alert.setTextColor(0xFFF2ECE6);
        alert.setShadowLayer(14 * dp, 0, 2 * dp, 0xE6000000);
        alert.setLetterSpacing(0.14f);
        alert.setAllCaps(true);
        alert.setGravity(Gravity.CENTER);
        alert.setMaxWidth(Math.round(metrics.widthPixels * 0.8f));
        alert.setFocusable(false);
        alert.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO);
        alert.setAlpha(0f);
        alert.setVisibility(View.GONE);
        Typeface face = null;
        try {
            face = UiFont.get(context, R.string.font_regular);
        } catch (Exception ignored) {
            // the system font is fine
        }
        alert.setTypeface(Typeface.create(face, Typeface.BOLD));
        FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.TOP | Gravity.CENTER_HORIZONTAL);
        // Between the top bar and the app name over the dock: the part of Home with nothing on it.
        params.topMargin = Math.round(metrics.heightPixels * 0.30f);
        root.addView(alert, 3, params);
        hideAlert = () -> alert.animate().alpha(0f).setDuration(700)
                .withEndAction(() -> alert.setVisibility(View.GONE)).start();
        if (withSound) loadSounds(context);
    }

    void setStyleMs(long ms) {
        styleMs = Math.max(0L, ms);
    }

    /**
     * A change's animator length: focus_style_ms when set, divided by the system's animator duration scale (0.5 on
     * this TV, which would halve it) so it lasts that long on screen; otherwise the style's own length.
     */
    private long length(long own) {
        if (styleMs <= 0) return own;
        float scale = ValueAnimator.getDurationScale();
        return scale > 0f ? Math.round(styleMs / scale) : styleMs;
    }

    private static FrameLayout.LayoutParams full() {
        return new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT);
    }

    /** A full-screen overlay, clear in the middle and the edge colour at the corners; hidden until faded in. */
    private static View shade(Context context, int edge, float radius) {
        GradientDrawable gradient = new GradientDrawable();
        gradient.setGradientType(GradientDrawable.RADIAL_GRADIENT);
        gradient.setColors(new int[] {0x00000000, 0x00000000, edge});
        gradient.setGradientRadius(radius);
        View view = new View(context);
        view.setBackground(gradient);
        view.setAlpha(0f);
        view.setVisibility(View.GONE);
        view.setFocusable(false);
        view.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO);
        return view;
    }

    /**
     * Brings next in over the picture on screen. done runs once the old picture is off screen: when the change
     * settles, or at once when a newer change cuts this one short.
     */
    void swap(Bitmap next, int style, int dx, int dy, Runnable done) {
        settle();
        incoming = next;
        incomingDone = done;
        top.setImageBitmap(next);
        top.setAlpha(0f);
        top.setScaleX(1f);
        top.setScaleY(1f);
        top.setTranslationX(0f);
        top.setTranslationY(0f);
        top.setVisibility(View.VISIBLE);
        if (!effects) style = FADE;
        switch (style) {
            case PUSH:
                push(dx, dy);
                break;
            case STATIC:
                tapeStatic();
                break;
            case FLICKER:
                flicker();
                break;
            case SLOW:
                fade(length(1100));
                break;
            default:
                fade(length(320));
                break;
        }
    }

    private void fade(long ms) {
        top.animate().alpha(1f).setDuration(ms).setInterpolator(new DecelerateInterpolator())
                .withEndAction(this::settle).start();
    }

    /** The new picture slides in a little from the side the focus moved to, settling from a slight zoom. */
    private void push(int dx, int dy) {
        top.setScaleX(1.05f);
        top.setScaleY(1.05f);
        top.setTranslationX(dx * 46 * dp);
        top.setTranslationY(dy * 30 * dp);
        top.animate().alpha(1f).scaleX(1f).scaleY(1f).translationX(0f).translationY(0f).setDuration(length(460))
                .setInterpolator(new DecelerateInterpolator(2f)).withEndAction(this::settle).start();
    }

    /** A third of a second of tape static over a shaking cut, like a VHS losing its tracking. */
    private void tapeStatic() {
        makeNoise();
        noise.setAlpha(0f);
        noise.setVisibility(View.VISIBLE);
        play(soundStatic, 0.3f, 0);
        ValueAnimator animator = ValueAnimator.ofFloat(0f, 1f);
        animator.setDuration(length(320));
        animator.setInterpolator(new LinearInterpolator());
        // A new grain about every 33 ms of a longer focus_style_ms, so the snow does not slow down with it.
        int grains = (int) Math.max(14, styleMs / 33);
        animator.addUpdateListener(a -> {
            float f = a.getAnimatedFraction();
            noise.setBackground(noiseFrames[(int) (f * grains) % noiseFrames.length]);
            noise.setAlpha(f < 0.35f ? f / 0.35f * 0.55f : 0.55f * (1f - (f - 0.35f) / 0.65f));
            top.setAlpha(f < 0.3f ? 0f : Math.min(1f, (f - 0.3f) / 0.4f));
            top.setTranslationX(f < 0.8f ? (random.nextFloat() - 0.5f) * 18 * dp : 0f);
        });
        endWithSettle(animator);
    }

    /** The new picture comes on like a failing bulb: two dips, then steady. Never more than 3 flashes a second. */
    private void flicker() {
        ValueAnimator animator = ValueAnimator.ofFloat(0f, 1f, 0.35f, 1f, 0.6f, 1f);
        // Its two dips stay under 3 flashes a second on screen, also with a shortened animator scale (0.5 here).
        long ms = length(560);
        float scale = ValueAnimator.getDurationScale();
        if (scale > 0f && ms * scale < 700f) ms = Math.round(700f / scale);
        animator.setDuration(ms);
        animator.setInterpolator(new LinearInterpolator());
        animator.addUpdateListener(a -> top.setAlpha((float) a.getAnimatedValue()));
        endWithSettle(animator);
    }

    private void endWithSettle(ValueAnimator animator) {
        swapAnimator = animator;
        animator.addListener(new AnimatorListenerAdapter() {
            @Override
            public void onAnimationEnd(Animator animation) {
                settle();
            }
        });
        animator.start();
    }

    /** Ends a change at once: the incoming picture becomes the bottom one and the old one can be released. */
    void settle() {
        Bitmap next = incoming;
        if (next == null) return;
        incoming = null;
        top.animate().cancel();
        ValueAnimator running = swapAnimator;
        swapAnimator = null;
        if (running != null) running.cancel();   // its end listener finds nothing left to settle
        bottom.setImageBitmap(next);
        top.setImageDrawable(null);
        top.setAlpha(0f);
        top.setScaleX(1f);
        top.setScaleY(1f);
        top.setTranslationX(0f);
        top.setTranslationY(0f);
        top.setVisibility(View.INVISIBLE);
        noise.setAlpha(0f);
        noise.setBackground(null);
        noise.setVisibility(View.GONE);
        Runnable done = incomingDone;
        incomingDone = null;
        if (done != null) done.run();
    }

    /**
     * The idle approach's look for a stage: the edges darken and the picture creeps closer with each one; the last
     * adds a red edge that beats like a heart and a jolt. Stage 0 sends it all away.
     */
    void approach(int stage) {
        stopHeart();
        if (!effects) return;
        boolean away = stage <= 0;
        fadeTo(vignette, away ? 0f : stage == 1 ? 0.45f : stage == 2 ? 0.72f : 0.92f, away ? 450 : 1600);
        fadeTo(danger, stage >= 3 ? 0.55f : 0f, away ? 450 : 1400);
        float scale = away ? 1f : stage == 1 ? 1.02f : stage == 2 ? 1.05f : 1.08f;
        layer.animate().cancel();
        layer.animate().scaleX(scale).scaleY(scale).setDuration(away ? 500 : 9000)
                .setInterpolator(new DecelerateInterpolator()).start();
        if (stage == 2) play(soundHeart, 0.45f, 1);
        if (stage >= 3) {
            ObjectAnimator.ofFloat(layer, View.TRANSLATION_X, 0f, 16 * dp, -13 * dp, 9 * dp, -5 * dp, 0f)
                    .setDuration(420).start();
            heart = ObjectAnimator.ofFloat(danger, View.ALPHA, 0.55f, 0.85f, 0.6f, 0.8f, 0.55f, 0.55f);
            heart.setDuration(1300);
            heart.setStartDelay(1400);
            heart.setRepeatCount(3);
            heart.start();
            play(soundHit, 0.6f, 0);
            play(soundHeart, 0.55f, 2);
        }
    }

    /** The rare picture's jolt: one red pulse at the edges (and a hit, with sounds on). */
    void rare() {
        if (!effects) return;
        danger.animate().cancel();
        danger.setVisibility(View.VISIBLE);
        ObjectAnimator pulse = ObjectAnimator.ofFloat(danger, View.ALPHA, 0f, 0.5f, 0f);
        pulse.setDuration(900);
        pulse.addListener(new AnimatorListenerAdapter() {
            @Override
            public void onAnimationEnd(Animator animation) {
                if (danger.getAlpha() == 0f) danger.setVisibility(View.GONE);
            }
        });
        pulse.start();
        play(soundHit, 0.4f, 0);
    }

    /** A line in large letters over the picture for a while (the approach's alerts); red for the last stage. */
    void alert(String text, boolean red, long holdMs) {
        if (text == null || text.trim().isEmpty()) return;
        alert.removeCallbacks(hideAlert);
        alert.animate().cancel();
        alert.setText(text.trim());
        alert.setTextColor(red ? 0xFFFF5A4F : 0xFFF2ECE6);
        alert.setVisibility(View.VISIBLE);
        alert.setAlpha(0f);
        alert.setTranslationY(14 * dp);
        alert.animate().alpha(1f).translationY(0f).setDuration(520).setInterpolator(new DecelerateInterpolator())
                .start();
        alert.postDelayed(hideAlert, holdMs);
    }

    void release() {
        settle();
        stopHeart();
        alert.removeCallbacks(hideAlert);
        if (sounds != null) {
            sounds.release();
            sounds = null;
        }
    }

    private void stopHeart() {
        if (heart != null) {
            heart.cancel();
            heart = null;
        }
    }

    private static void fadeTo(View view, float alpha, long ms) {
        view.animate().cancel();
        if (alpha > 0f) {
            view.setVisibility(View.VISIBLE);
        } else if (view.getVisibility() != View.VISIBLE) {
            return;
        }
        view.animate().alpha(alpha).setDuration(ms).withEndAction(() -> {
            if (alpha == 0f) view.setVisibility(View.GONE);
        }).start();
    }

    /** Three small frames of grey noise with darker bands, stretched without filtering into chunky tape static. */
    private void makeNoise() {
        if (noiseFrames[0] != null) return;
        int w = 192, h = 108;
        for (int f = 0; f < noiseFrames.length; f++) {
            int[] pixels = new int[w * h];
            int band = random.nextInt(h);
            for (int y = 0; y < h; y++) {
                boolean dark = Math.abs(y - band) < 6 || (y + f * 7) % 37 < 2;
                for (int x = 0; x < w; x++) {
                    int v = random.nextInt(256);
                    if (dark) v /= 3;
                    pixels[y * w + x] = 0xFF000000 | (v << 16) | (v << 8) | v;
                }
            }
            BitmapDrawable drawable = new BitmapDrawable(resources, Bitmap.createBitmap(pixels, w, h, Bitmap.Config.ARGB_8888));
            drawable.setFilterBitmap(false);
            noiseFrames[f] = drawable;
        }
    }

    private void loadSounds(Context context) {
        try {
            sounds = new SoundPool.Builder().setMaxStreams(3).setAudioAttributes(new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()).build();
            soundStatic = sounds.load(context, R.raw.fx_estatica, 1);
            soundHeart = sounds.load(context, R.raw.fx_coracao, 1);
            soundHit = sounds.load(context, R.raw.fx_impacto, 1);
        } catch (Exception e) {
            sounds = null;
        }
    }

    private void play(int sound, float volume, int loop) {
        if (sounds != null && sound != 0) sounds.play(sound, volume, volume, 1, loop, 1f);
    }
}
