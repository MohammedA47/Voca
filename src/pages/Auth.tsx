import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion, AnimatePresence, LayoutGroup } from 'framer-motion';
import { Mail, Lock, Loader2, ArrowLeft, ArrowRight, UserCircle, Eye, EyeOff } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Checkbox } from '@/components/ui/checkbox';
import { useAuth } from '@/hooks/useAuth';
import { useToast } from '@/hooks/use-toast';
import { z } from 'zod';

const signInSchema = z.object({
  email: z.string().email('Please enter a valid email address'),
  password: z.string()
    .min(6, 'Password must be at least 6 characters')
    .max(50, 'Password must be less than 50 characters'),
});

const signUpSchema = signInSchema.extend({
  firstName: z.string().trim().min(1, 'First name is required').max(50),
  lastName: z.string().trim().min(1, 'Last name is required').max(50),
  confirmPassword: z.string().min(6, 'Please confirm your password'),
  age: z.number().int().min(5, 'Age must be at least 5').max(120, 'Age must be less than 120'),
  gender: z.enum(['male', 'female'], { required_error: 'Please select a gender' }),
  terms: z.literal(true, { errorMap: () => ({ message: 'You must agree to the terms' }) }),
}).refine((data) => data.password === data.confirmPassword, {
  message: 'Passwords do not match',
  path: ['confirmPassword'],
});

const genderOptions = [
  { value: 'male', label: 'Male' },
  { value: 'female', label: 'Female' },
] as const;

type AuthMode = 'signin' | 'signup' | 'forgot';

export default function Auth() {
  const [mode, setMode] = useState<AuthMode>('signin');
  const isSignUp = mode === 'signup';
  const isForgot = mode === 'forgot';
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [age, setAge] = useState('');
  const [gender, setGender] = useState('');
  const [termsAccepted, setTermsAccepted] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const { user, loading, signUp, signIn, resetPassword } = useAuth();
  const navigate = useNavigate();
  const { toast } = useToast();

  useEffect(() => {
    if (!loading && user) {
      navigate('/');
    }
  }, [user, loading, navigate]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    // Forgot password flow
    if (isForgot) {
      if (!email || !z.string().email().safeParse(email).success) {
        toast({ title: 'Invalid email', description: 'Please enter a valid email address.', variant: 'destructive' });
        return;
      }
      setIsLoading(true);
      const { error } = await resetPassword(email);
      setIsLoading(false);
      if (error) {
        toast({ title: 'Error', description: error.message, variant: 'destructive' });
      } else {
        toast({ title: 'Email sent! 📧', description: 'Check your inbox for a password reset link.' });
        setMode('signin');
      }
      return;
    }

    if (isSignUp) {
      const validation = signUpSchema.safeParse({
        email,
        password,
        confirmPassword,
        firstName,
        lastName,
        age: age ? parseInt(age) : undefined,
        gender: gender || undefined,
        terms: termsAccepted,
      });
      if (!validation.success) {
        toast({
          title: 'Validation Error',
          description: validation.error.errors[0].message,
          variant: 'destructive',
        });
        return;
      }
    } else {
      const validation = signInSchema.safeParse({ email, password });
      if (!validation.success) {
        toast({
          title: 'Validation Error',
          description: validation.error.errors[0].message,
          variant: 'destructive',
        });
        return;
      }
    }

    setIsLoading(true);

    if (isSignUp) {
      const { error } = await signUp(email, password, {
        firstName,
        lastName,
        age: parseInt(age),
        gender,
      });
      if (error) {
        const message = error.message.includes('already registered')
          ? 'Username already taken'
          : error.message;
        toast({
          title: 'Sign up failed',
          description: message,
          variant: 'destructive',
        });
      } else {
        toast({
          title: 'Account created! 🎉',
          description: 'Please check your email to verify your account before signing in.',
        });
        setMode('signin');
        setFirstName('');
        setLastName('');
        setAge('');
        setGender('');
        setPassword('');
        setConfirmPassword('');
        setTermsAccepted(false);
      }
    } else {
      const { error } = await signIn(email, password);
      if (error) {
        const isUnconfirmed = error.message?.toLowerCase().includes('email not confirmed');
        toast({
          title: isUnconfirmed ? 'Email not verified' : 'Sign in failed',
          description: isUnconfirmed
            ? 'Please verify your email before signing in.'
            : 'Invalid username or password',
          variant: 'destructive',
        });
      } else {
        navigate('/');
      }
    }

    setIsLoading(false);
  };

  const switchMode = () => {
    setMode(isSignUp ? 'signin' : 'signup');
  };

  if (loading) {
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
        {/* Header */}
        <AnimatePresence mode="wait">
          <motion.div
            key={mode}
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -16 }}
            transition={{ duration: 0.3, ease: 'easeOut' }}
            className="mb-6"
          >
            <h1 className="font-display text-3xl font-bold text-foreground">
              {isForgot ? 'Reset Password' : isSignUp ? 'Create Account' : 'Welcome Back'}
            </h1>
            <p className="mt-1.5 text-sm text-muted-foreground">
              {isForgot
                ? 'Enter your email to receive a reset link.'
                : isSignUp
                  ? 'Join our community to get started.'
                  : 'Sign in to continue learning.'}
            </p>
          </motion.div>
        </AnimatePresence>

        {/* Form */}
        <LayoutGroup>
          <motion.form
            layout
            onSubmit={handleSubmit}
            className="flex w-full max-w-sm flex-col gap-4"
            transition={{ layout: { duration: 0.35, ease: 'easeOut' } }}
          >
            {/* Sign Up fields - fade in/out */}
            <AnimatePresence initial={false}>
              {isSignUp && (
                <motion.div
                  key="names"
                  initial={{ opacity: 0, height: 0 }}
                  animate={{ opacity: 1, height: 'auto' }}
                  exit={{ opacity: 0, height: 0 }}
                  transition={{ duration: 0.3, ease: 'easeOut' }}
                  className="overflow-hidden"
                >
                  <div className="grid grid-cols-2 gap-3">
                    <div className="space-y-1.5">
                      <Label className="text-xs font-medium text-muted-foreground">First Name</Label>
                      <div className="relative">
                        <UserCircle className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground/50" />
                        <Input
                          type="text"
                          placeholder="John"
                          value={firstName}
                          onChange={(e) => setFirstName(e.target.value)}
                          className="h-12 rounded-xl border-border/40 bg-muted/30 pl-10 text-sm placeholder:text-muted-foreground/40"
                          required
                        />
                      </div>
                    </div>
                    <div className="space-y-1.5">
                      <Label className="text-xs font-medium text-muted-foreground">Last Name</Label>
                      <Input
                        type="text"
                        placeholder="Doe"
                        value={lastName}
                        onChange={(e) => setLastName(e.target.value)}
                        className="h-12 rounded-xl border-border/40 bg-muted/30 text-sm placeholder:text-muted-foreground/40"
                        required
                      />
                    </div>
                  </div>
                </motion.div>
              )}
            </AnimatePresence>

            {/* Email - shared, animates position */}
            <motion.div layout transition={{ layout: { duration: 0.35, ease: 'easeOut' } }} className="space-y-1.5">
              <Label className="text-xs font-medium text-muted-foreground">Email</Label>
              <div className="relative">
                <Mail className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground/50" />
                <Input
                  type="email"
                  placeholder="Enter your email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="h-12 rounded-xl border-border/40 bg-muted/30 pl-10 text-sm placeholder:text-muted-foreground/40"
                  required
                />
              </div>
            </motion.div>

            {/* Password - shared, animates position (hidden in forgot mode) */}
            <AnimatePresence initial={false}>
              {!isForgot && (
                <motion.div
                  key="password"
                  layout
                  initial={{ opacity: 0, height: 0 }}
                  animate={{ opacity: 1, height: 'auto' }}
                  exit={{ opacity: 0, height: 0 }}
                  transition={{ duration: 0.3, ease: 'easeOut' }}
                  className="space-y-1.5 overflow-hidden"
                >
                  <Label className="text-xs font-medium text-muted-foreground">Password</Label>
                  <div className="relative">
                    <Lock className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground/50" />
                    <Input
                      type={showPassword ? 'text' : 'password'}
                      placeholder={isSignUp ? 'Create a password' : 'Enter your password'}
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      className="h-12 rounded-xl border-border/40 bg-muted/30 pl-10 pr-10 text-sm placeholder:text-muted-foreground/40"
                      required
                    />
                    <button
                      type="button"
                      onClick={() => setShowPassword(!showPassword)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground/50 transition-colors hover:text-foreground"
                    >
                      {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                    </button>
                  </div>
                  {/* Forgot password link */}
                  {!isSignUp && (
                    <div className="flex justify-end pt-0.5">
                      <button
                        type="button"
                        onClick={() => setMode('forgot')}
                        className="text-xs text-muted-foreground transition-colors hover:text-primary"
                      >
                        Forgot password?
                      </button>
                    </div>
                  )}
                </motion.div>
              )}
            </AnimatePresence>

            {/* Confirm Password - fade in/out */}
            <AnimatePresence initial={false}>
              {isSignUp && (
                <motion.div
                  key="confirm-pw"
                  initial={{ opacity: 0, height: 0 }}
                  animate={{ opacity: 1, height: 'auto' }}
                  exit={{ opacity: 0, height: 0 }}
                  transition={{ duration: 0.3, ease: 'easeOut' }}
                  className="overflow-hidden"
                >
                  <div className="space-y-1.5">
                    <Label className="text-xs font-medium text-muted-foreground">Confirm Password</Label>
                    <div className="relative">
                      <Lock className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground/50" />
                      <Input
                        type={showConfirmPassword ? 'text' : 'password'}
                        placeholder="Confirm your password"
                        value={confirmPassword}
                        onChange={(e) => setConfirmPassword(e.target.value)}
                        className="h-12 rounded-xl border-border/40 bg-muted/30 pl-10 pr-10 text-sm placeholder:text-muted-foreground/40"
                        required
                      />
                      <button
                        type="button"
                        onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                        className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground/50 transition-colors hover:text-foreground"
                      >
                        {showConfirmPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                      </button>
                    </div>
                  </div>
                </motion.div>
              )}
            </AnimatePresence>

            {/* Age, Gender, Terms - fade in/out */}
            <AnimatePresence initial={false}>
              {isSignUp && (
                <motion.div
                  key="extra-fields"
                  initial={{ opacity: 0, height: 0 }}
                  animate={{ opacity: 1, height: 'auto' }}
                  exit={{ opacity: 0, height: 0 }}
                  transition={{ duration: 0.3, ease: 'easeOut' }}
                  className="flex flex-col gap-4 overflow-hidden"
                >
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
                      required
                    />
                  </div>

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

                  <div className="flex items-start gap-2.5 pt-1">
                    <Checkbox
                      id="terms"
                      checked={termsAccepted}
                      onCheckedChange={(checked) => setTermsAccepted(checked === true)}
                      className="mt-0.5 border-border/60 data-[state=checked]:border-primary data-[state=checked]:bg-primary"
                    />
                    <label htmlFor="terms" className="text-xs leading-relaxed text-muted-foreground">
                      I agree to the{' '}
                      <span className="text-primary">Terms of Service</span> and{' '}
                      <span className="text-primary">Privacy Policy</span>.
                    </label>
                  </div>
                </motion.div>
              )}
            </AnimatePresence>

            {/* Submit - animates position */}
            <motion.div layout transition={{ layout: { duration: 0.35, ease: 'easeOut' } }}>
              <Button
                type="submit"
                className="h-12 w-full rounded-xl bg-gradient-gold text-sm font-semibold text-primary-foreground shadow-gold transition-all hover:opacity-90 active:scale-[0.98]"
                disabled={isLoading}
              >
                {isLoading ? (
                  <Loader2 className="h-4 w-4 animate-spin" />
                ) : (
                  <span className="flex items-center gap-2">
                    {isForgot ? 'Send Reset Link' : isSignUp ? 'Sign Up' : 'Sign In'}
                    <ArrowRight className="h-4 w-4" />
                  </span>
                )}
              </Button>
            </motion.div>

            {/* Switch mode - animates position */}
            <motion.p layout transition={{ layout: { duration: 0.35, ease: 'easeOut' } }} className="text-center text-sm text-muted-foreground">
              {isForgot ? (
                <>Remember your password?{' '}<button type="button" onClick={() => setMode('signin')} className="font-semibold text-primary">Sign in</button></>
              ) : isSignUp ? (
                <>Already have an account?{' '}<button type="button" onClick={switchMode} className="font-semibold text-primary">Log in</button></>
              ) : (
                <>Don't have an account?{' '}<button type="button" onClick={switchMode} className="font-semibold text-primary">Sign up</button></>
              )}
            </motion.p>
          </motion.form>
        </LayoutGroup>
      </div>
    </div>
  );
}
