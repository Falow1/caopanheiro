class OnboardingStep {
  const OnboardingStep(this.label, this.completed, {this.verified = true});
  final bool verified;
  final String label;
  final bool completed;
}
