import 'package:flutter/material.dart';

class WorkoutKeypad extends StatelessWidget {
  final ValueChanged<String> onNumberTap;
  final VoidCallback onBackspace;
  final VoidCallback onDone;
  final VoidCallback onMoveRight;
  final VoidCallback onMoveDown;
  final VoidCallback onFillDown;

  const WorkoutKeypad({
    super.key,
    required this.onNumberTap,
    required this.onBackspace,
    required this.onDone,
    required this.onMoveRight,
    required this.onMoveDown,
    required this.onFillDown,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      constraints: const BoxConstraints(maxHeight: 240),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRow(
              children: [
                _key('1', () => onNumberTap('1')),
                _key('2', () => onNumberTap('2')),
                _key('3', () => onNumberTap('3')),
                _fnKey('⌫', onBackspace),
              ],
            ),
            _buildRow(
              children: [
                _key('4', () => onNumberTap('4')),
                _key('5', () => onNumberTap('5')),
                _key('6', () => onNumberTap('6')),
                _fnKey('Done', onDone),
              ],
            ),
            _buildRow(
              children: [
                _key('7', () => onNumberTap('7')),
                _key('8', () => onNumberTap('8')),
                _key('9', () => onNumberTap('9')),
                _fnKey('→', onMoveRight),
              ],
            ),
            _buildRow(
              children: [
                _fnKey('↓↓', onFillDown),
                _key('0', () => onNumberTap('0')),
                _key('.', () => onNumberTap('.')),
                _fnKey('↓', onMoveDown),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow({required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: children
            .map(
              (child) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: child,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _key(String label, VoidCallback onTap) {
    return _padButton(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _fnKey(String label, VoidCallback onTap) {
    Widget child;

    if (label == '⌫') {
      child = const Icon(Icons.backspace, color: Colors.white, size: 26);
    } else if (label == 'Done') {
      child = const Icon(Icons.check_circle, color: Colors.white, size: 26);
    } else if (label == '↓↓') {
      child = const Icon(Icons.keyboard_double_arrow_down, color: Colors.white, size: 28);
    } else if (label == '↓') {
      child = const Icon(Icons.arrow_downward, color: Colors.white, size: 26);
    } else if (label == '→') {
      child = const Icon(Icons.arrow_forward, color: Colors.white, size: 26);
    } else {
      child = Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return _padButton(
      onTap: onTap,
      child: child,
    );
  }

  Widget _padButton({
    required VoidCallback onTap,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(child: child),
      ),
    );
  }


}
