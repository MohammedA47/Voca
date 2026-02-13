import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { ArrowLeft, UserCircle, Save, Loader2, LogOut } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { useAuth } from '@/hooks/useAuth';
import { useToast } from '@/hooks/use-toast';
import { supabase } from '@/integrations/supabase/client';

const genderOptions = [
  { value: 'male', label: 'Male' },
  { value: 'female', label: 'Female' },
] as const;

interface ProfileData {
  first_name: string;
  last_name: string;
  age: number | null;
  gender: string | null;
  username: string;
}

export default function Profile() {
  const { user, loading, signOut } = useAuth();
  const navigate = useNavigate();
  const { toast } = useToast();

  const [profile, setProfile] = useState<ProfileData | null>(null);
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [age, setAge] = useState('');
  const [gender, setGender] = useState('');
  const [isSaving, setIsSaving] = useState(false);
  const [isFetching, setIsFetching] = useState(true);
  const [hasChanges, setHasChanges] = useState(false);

  useEffect(() => {
    if (!loading && !user) {
      navigate('/auth');
    }
  }, [user, loading, navigate]);

  useEffect(() => {
    if (!user) return;

    const fetchProfile = async () => {
      const { data, error } = await supabase
        .from('profiles')
        .select('first_name, last_name, age, gender, username')
        .eq('id', user.id)
        .single();

      if (error) {
        toast({ title: 'Error loading profile', description: error.message, variant: 'destructive' });
      } else if (data) {
        setProfile(data);
        setFirstName(data.first_name ?? '');
        setLastName(data.last_name ?? '');
        setAge(data.age != null ? String(data.age) : '');
        setGender(data.gender ?? '');
      }
      setIsFetching(false);
    };

    fetchProfile();
  }, [user, toast]);

  // Track changes
  useEffect(() => {
    if (!profile) return;
    const changed =
      firstName !== (profile.first_name ?? '') ||
      lastName !== (profile.last_name ?? '') ||
      age !== (profile.age != null ? String(profile.age) : '') ||
      gender !== (profile.gender ?? '');
    setHasChanges(changed);
  }, [firstName, lastName, age, gender, profile]);

  const handleSave = async () => {
    if (!user) return;

    if (!firstName.trim() || !lastName.trim()) {
      toast({ title: 'Missing fields', description: 'First and last name are required.', variant: 'destructive' });
      return;
    }

    const parsedAge = age ? parseInt(age) : null;
    if (parsedAge !== null && (parsedAge < 5 || parsedAge > 120)) {
      toast({ title: 'Invalid age', description: 'Age must be between 5 and 120.', variant: 'destructive' });
      return;
    }

    setIsSaving(true);
    const { error } = await supabase
      .from('profiles')
      .update({
        first_name: firstName.trim(),
        last_name: lastName.trim(),
        age: parsedAge,
        gender: gender || null,
      })
      .eq('id', user.id);

    setIsSaving(false);

    if (error) {
      toast({ title: 'Error saving', description: error.message, variant: 'destructive' });
    } else {
      setProfile((prev) =>
        prev
          ? { ...prev, first_name: firstName.trim(), last_name: lastName.trim(), age: parsedAge, gender: gender || null }
          : prev
      );
      toast({ title: 'Profile updated! ✨' });
    }
  };

  const handleSignOut = async () => {
    await signOut();
    navigate('/auth');
  };

  if (loading || isFetching) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-background">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>
    );
  }

  return (
    <div className="relative flex min-h-[100dvh] flex-col bg-background">
      {/* Decorative gradient blob */}
      <div className="pointer-events-none absolute left-1/2 top-0 -translate-x-1/2">
        <div className="h-[340px] w-[340px] rounded-full bg-primary/10 blur-[100px]" />
      </div>

      {/* Back button */}
      <motion.button
        initial={{ opacity: 0, x: -12 }}
        animate={{ opacity: 1, x: 0 }}
        onClick={() => navigate('/')}
        className="absolute left-4 top-4 z-10 flex items-center gap-1.5 rounded-full bg-muted/60 px-3 py-2 text-sm text-muted-foreground backdrop-blur-sm transition-colors hover:bg-muted hover:text-foreground"
      >
        <ArrowLeft className="h-4 w-4" />
      </motion.button>

      {/* Content */}
      <div className="flex flex-1 flex-col items-center justify-center px-6 pb-8 pt-16">
        {/* Avatar & Header */}
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
          className="mb-6 flex flex-col items-center"
        >
          <div className="mb-3 flex h-20 w-20 items-center justify-center rounded-full bg-primary/10">
            <UserCircle className="h-12 w-12 text-primary" />
          </div>
          <h1 className="font-display text-3xl font-bold text-foreground">Profile</h1>
          <p className="mt-1 text-sm text-muted-foreground">{profile?.username ?? user?.email}</p>
        </motion.div>

        {/* Form */}
        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.15 }}
          className="flex w-full max-w-sm flex-col gap-4"
        >
          {/* Names */}
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <Label className="text-xs font-medium text-muted-foreground">First Name</Label>
              <Input
                type="text"
                placeholder="John"
                value={firstName}
                onChange={(e) => setFirstName(e.target.value)}
                className="h-12 rounded-xl border-border/40 bg-muted/30 text-sm placeholder:text-muted-foreground/40"
              />
            </div>
            <div className="space-y-1.5">
              <Label className="text-xs font-medium text-muted-foreground">Last Name</Label>
              <Input
                type="text"
                placeholder="Doe"
                value={lastName}
                onChange={(e) => setLastName(e.target.value)}
                className="h-12 rounded-xl border-border/40 bg-muted/30 text-sm placeholder:text-muted-foreground/40"
              />
            </div>
          </div>

          {/* Age */}
          <div className="space-y-1.5">
            <Label className="text-xs font-medium text-muted-foreground">Age</Label>
            <Input
              type="number"
              placeholder="25"
              value={age}
              onChange={(e) => setAge(e.target.value)}
              className="h-12 rounded-xl border-border/40 bg-muted/30 text-sm placeholder:text-muted-foreground/40"
              min={5}
              max={120}
            />
          </div>

          {/* Gender */}
          <div className="space-y-2">
            <Label className="text-xs font-medium text-muted-foreground">Gender</Label>
            <div className="flex gap-2">
              {genderOptions.map((option) => (
                <button
                  key={option.value}
                  type="button"
                  onClick={() => setGender(option.value)}
                  className={`flex-1 rounded-xl border px-3 py-2.5 text-sm font-medium transition-all ${
                    gender === option.value
                      ? 'border-primary bg-primary/10 text-primary'
                      : 'border-border/40 bg-muted/30 text-muted-foreground hover:border-primary/40'
                  }`}
                >
                  {option.label}
                </button>
              ))}
            </div>
          </div>

          {/* Save Button */}
          <Button
            onClick={handleSave}
            className="h-12 w-full rounded-xl bg-gradient-gold text-sm font-semibold text-primary-foreground shadow-gold transition-all hover:opacity-90 active:scale-[0.98] disabled:opacity-50"
            disabled={isSaving || !hasChanges}
          >
            {isSaving ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <span className="flex items-center gap-2">
                <Save className="h-4 w-4" />
                Save Changes
              </span>
            )}
          </Button>

          {/* Sign Out */}
          <button
            onClick={handleSignOut}
            className="mt-2 flex items-center justify-center gap-2 rounded-xl border border-destructive/30 py-3 text-sm font-medium text-destructive transition-colors hover:bg-destructive/10"
          >
            <LogOut className="h-4 w-4" />
            Sign Out
          </button>
        </motion.div>
      </div>
    </div>
  );
}
