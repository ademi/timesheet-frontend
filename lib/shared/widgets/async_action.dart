import 'package:flutter/material.dart';

class ButtonLoadingIndicator extends StatelessWidget {
  const ButtonLoadingIndicator({
    super.key,
    this.color,
    this.size = 16,
    this.strokeWidth = 2,
  });

  final Color? color;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(color: color, strokeWidth: strokeWidth),
    );
  }
}

class AsyncButtonChild extends StatelessWidget {
  const AsyncButtonChild({
    super.key,
    required this.isLoading,
    required this.child,
    this.indicatorColor,
  });

  final bool isLoading;
  final Widget child;
  final Color? indicatorColor;

  @override
  Widget build(BuildContext context) {
    return isLoading ? ButtonLoadingIndicator(color: indicatorColor) : child;
  }
}

class AsyncElevatedButton extends StatelessWidget {
  const AsyncElevatedButton({
    super.key,
    required this.onPressed,
    required this.isLoading,
    required this.child,
    this.style,
  });

  final VoidCallback onPressed;
  final bool isLoading;
  final Widget child;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: style,
      child: AsyncButtonChild(
        isLoading: isLoading,
        indicatorColor: style?.foregroundColor?.resolve({}),
        child: child,
      ),
    );
  }
}

class AsyncFilledButton extends StatelessWidget {
  const AsyncFilledButton({
    super.key,
    required this.onPressed,
    required this.isLoading,
    required this.child,
    this.style,
  });

  final VoidCallback onPressed;
  final bool isLoading;
  final Widget child;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: style,
      child: AsyncButtonChild(
        isLoading: isLoading,
        indicatorColor: style?.foregroundColor?.resolve({}),
        child: child,
      ),
    );
  }
}

class AsyncOutlinedButton extends StatelessWidget {
  const AsyncOutlinedButton({
    super.key,
    required this.onPressed,
    required this.isLoading,
    required this.child,
    this.style,
  });

  final VoidCallback onPressed;
  final bool isLoading;
  final Widget child;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: style,
      child: AsyncButtonChild(
        isLoading: isLoading,
        indicatorColor: style?.foregroundColor?.resolve({}),
        child: child,
      ),
    );
  }
}

class AsyncTextButton extends StatelessWidget {
  const AsyncTextButton({
    super.key,
    required this.onPressed,
    required this.isLoading,
    required this.child,
    this.style,
  });

  final VoidCallback onPressed;
  final bool isLoading;
  final Widget child;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: isLoading ? null : onPressed,
      style: style,
      child: AsyncButtonChild(
        isLoading: isLoading,
        indicatorColor: style?.foregroundColor?.resolve({}),
        child: child,
      ),
    );
  }
}

class AsyncElevatedButtonIcon extends StatelessWidget {
  const AsyncElevatedButtonIcon({
    super.key,
    required this.onPressed,
    required this.isLoading,
    required this.icon,
    required this.label,
    this.style,
  });

  final VoidCallback onPressed;
  final bool isLoading;
  final Widget icon;
  final Widget label;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      style: style,
      icon: isLoading ? AsyncButtonChild(isLoading: true, child: icon) : icon,
      label: isLoading ? const SizedBox.shrink() : label,
    );
  }
}

class AsyncIconButton extends StatelessWidget {
  const AsyncIconButton({
    super.key,
    required this.onPressed,
    required this.isLoading,
    required this.icon,
    this.tooltip,
    this.color,
  });

  final VoidCallback onPressed;
  final bool isLoading;
  final Widget icon;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: isLoading ? null : onPressed,
      tooltip: tooltip,
      color: color,
      icon: isLoading ? ButtonLoadingIndicator(color: color) : icon,
    );
  }
}
