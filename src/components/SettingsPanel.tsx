import { motion } from 'framer-motion';
import { X, Gauge, Shuffle, Clock, Repeat, Volume2, Sun, Moon, Monitor, Globe } from 'lucide-react';
import { Slider } from '@/components/ui/slider';
import { Switch } from '@/components/ui/switch';
import { cn } from '@/lib/utils';
import { useTheme } from 'next-themes';
import type { PhoneticAccent } from '@/pages/Index';

interface SettingsPanelProps {
  isLooping: boolean;
  speed: number;
  isRandomSpeed: boolean;
  loopGap: number;
  phoneticAccent: PhoneticAccent;
  onToggleLoop: () => void;
  onSpeedChange: (speed: number) => void;
  onRandomSpeedToggle: () => void;
  onLoopGapChange: (gap: number) => void;
  onPhoneticAccentChange: (accent: PhoneticAccent) => void;
  onClose: () => void;
}

export function SettingsPanel({
  isLooping,
  speed,
  isRandomSpeed,
  loopGap,
  phoneticAccent,
  onToggleLoop,
  onSpeedChange,
  onRandomSpeedToggle,
  onLoopGapChange,
  onPhoneticAccentChange,
  onClose,
}: SettingsPanelProps) {
  const { theme, setTheme } = useTheme();

  const themeOptions = [
    { id: 'light', label: 'Light', icon: Sun },
    { id: 'dark', label: 'Dark', icon: Moon },
    { id: 'system', label: 'System', icon: Monitor },
  ];

  return (
    <motion.div
      initial={{ opacity: 0, y: '100%' }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: '100%' }}
      transition={{ duration: 0.3, ease: 'easeOut' }}
      className="fixed inset-0 z-50 flex flex-col bg-background"
    >
      {/* Header */}
      <div className="flex items-center justify-between border-b border-border p-4">
        <h2 className="font-display text-lg font-semibold text-foreground">Settings</h2>
        <button
          onClick={onClose}
          className="rounded-full p-2 text-muted-foreground transition-colors hover:bg-muted"
        >
          <X className="h-5 w-5" />
        </button>
      </div>

      {/* Settings Content */}
      <div className="flex-1 overflow-y-auto p-4 pb-24">
        <div className="space-y-6">
          {/* Playback Section */}
          <section>
            <div className="mb-4 flex items-center gap-2">
              <Volume2 className="h-5 w-5 text-oxford-gold" />
              <h3 className="font-display text-base font-semibold text-foreground">
                Playback Settings
              </h3>
            </div>

            <div className="space-y-4 rounded-xl border-2 border-border bg-card p-4">
              {/* Loop Toggle */}
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div className="flex h-10 w-10 items-center justify-center rounded-full bg-oxford-gold/10">
                    <Repeat className="h-5 w-5 text-oxford-gold" />
                  </div>
                  <div>
                    <p className="text-sm font-medium text-foreground">Loop Playback</p>
                    <p className="text-xs text-muted-foreground">Repeat the current word</p>
                  </div>
                </div>
                <Switch
                  checked={isLooping}
                  onCheckedChange={onToggleLoop}
                />
              </div>

              {/* Speed Control */}
              <div className="space-y-3 border-t border-border pt-4">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <div className="flex h-10 w-10 items-center justify-center rounded-full bg-oxford-gold/10">
                      <Gauge className="h-5 w-5 text-oxford-gold" />
                    </div>
                    <div>
                      <p className="text-sm font-medium text-foreground">Playback Speed</p>
                      <p className="text-xs text-muted-foreground">Adjust pronunciation speed</p>
                    </div>
                  </div>
                  <span className="rounded-full bg-primary px-3 py-1 font-mono text-xs font-semibold text-primary-foreground">
                    {isRandomSpeed ? 'Random' : `${speed.toFixed(1)}x`}
                  </span>
                </div>
                
                <Slider
                  value={[speed]}
                  min={0.5}
                  max={1.5}
                  step={0.1}
                  onValueChange={([value]) => onSpeedChange(value)}
                  disabled={isRandomSpeed}
                  className={cn('mt-2', isRandomSpeed && 'opacity-50')}
                />
                
                <div className="flex justify-between text-xs text-muted-foreground">
                  <span>0.5x</span>
                  <span>1.0x</span>
                  <span>1.5x</span>
                </div>
              </div>

              {/* Random Speed Toggle */}
              <div className="flex items-center justify-between border-t border-border pt-4">
                <div className="flex items-center gap-3">
                  <div className="flex h-10 w-10 items-center justify-center rounded-full bg-oxford-gold/10">
                    <Shuffle className="h-5 w-5 text-oxford-gold" />
                  </div>
                  <div>
                    <p className="text-sm font-medium text-foreground">Random Speed</p>
                    <p className="text-xs text-muted-foreground">Vary speed automatically</p>
                  </div>
                </div>
                <Switch
                  checked={isRandomSpeed}
                  onCheckedChange={onRandomSpeedToggle}
                />
              </div>

              {/* Loop Gap Control */}
              <div className="space-y-3 border-t border-border pt-4">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <div className="flex h-10 w-10 items-center justify-center rounded-full bg-oxford-gold/10">
                      <Clock className="h-5 w-5 text-oxford-gold" />
                    </div>
                    <div>
                      <p className="text-sm font-medium text-foreground">Repeat Gap</p>
                      <p className="text-xs text-muted-foreground">Pause between loops</p>
                    </div>
                  </div>
                  <span className="rounded-full bg-primary px-3 py-1 font-mono text-xs font-semibold text-primary-foreground">
                    {loopGap.toFixed(1)}s
                  </span>
                </div>
                
                <Slider
                  value={[loopGap]}
                  min={0.5}
                  max={5}
                  step={0.5}
                  onValueChange={([value]) => onLoopGapChange(value)}
                  className="mt-2"
                />
                
                <div className="flex justify-between text-xs text-muted-foreground">
                  <span>0.5s</span>
                  <span>2.5s</span>
                  <span>5s</span>
                </div>
              </div>
            </div>
          </section>

          {/* Pronunciation Section */}
          <section>
            <div className="mb-4 flex items-center gap-2">
              <Globe className="h-5 w-5 text-oxford-gold" />
              <h3 className="font-display text-base font-semibold text-foreground">
                Pronunciation
              </h3>
            </div>

            <div className="rounded-xl border-2 border-border bg-card p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-foreground">Phonetic Accent</p>
                  <p className="text-xs text-muted-foreground">Choose US or UK pronunciation</p>
                </div>
              </div>
              
              <div className="mt-4 flex gap-2">
                {[
                  { id: 'us', label: 'US', flag: '🇺🇸' },
                  { id: 'uk', label: 'UK', flag: '🇬🇧' },
                ].map((option) => {
                  const isActive = phoneticAccent === option.id;
                  return (
                    <button
                      key={option.id}
                      onClick={() => onPhoneticAccentChange(option.id as PhoneticAccent)}
                      className={cn(
                        'flex flex-1 flex-col items-center gap-2 rounded-lg border-2 p-3 transition-all',
                        isActive
                          ? 'border-oxford-gold bg-oxford-gold/10 text-oxford-gold'
                          : 'border-border text-muted-foreground hover:border-oxford-gold/50'
                      )}
                    >
                      <span className="text-xl">{option.flag}</span>
                      <span className="text-xs font-medium">{option.label}</span>
                    </button>
                  );
                })}
              </div>
            </div>
          </section>

          {/* Appearance Section */}
          <section>
            <div className="mb-4 flex items-center gap-2">
              <Sun className="h-5 w-5 text-oxford-gold" />
              <h3 className="font-display text-base font-semibold text-foreground">
                Appearance
              </h3>
            </div>

            <div className="rounded-xl border-2 border-border bg-card p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-foreground">Theme</p>
                  <p className="text-xs text-muted-foreground">Choose your preferred theme</p>
                </div>
              </div>
              
              <div className="mt-4 flex gap-2">
                {themeOptions.map((option) => {
                  const Icon = option.icon;
                  const isActive = theme === option.id;
                  return (
                    <button
                      key={option.id}
                      onClick={() => setTheme(option.id)}
                      className={cn(
                        'flex flex-1 flex-col items-center gap-2 rounded-lg border-2 p-3 transition-all',
                        isActive
                          ? 'border-oxford-gold bg-oxford-gold/10 text-oxford-gold'
                          : 'border-border text-muted-foreground hover:border-oxford-gold/50'
                      )}
                    >
                      <Icon className="h-5 w-5" />
                      <span className="text-xs font-medium">{option.label}</span>
                    </button>
                  );
                })}
              </div>
            </div>
          </section>
        </div>
      </div>
    </motion.div>
  );
}
