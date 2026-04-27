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
      color: const Color(0xFF0F0F0F),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
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
    return OutlinedButton(
      onPressed: onTap,
      style: _keyStyle(),
      child: Text(label, style: const TextStyle(fontSize: 18)),
    );
  }

  Widget _fnKey(String label, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: _keyStyle(backgroundColor: const Color(0xFF1D1D1D)),
      child: Text(label, style: const TextStyle(fontSize: 16)),
    );
  }

  ButtonStyle _keyStyle({Color backgroundColor = const Color(0xFF151515)}) {
    return OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: backgroundColor,
      side: const BorderSide(color: Colors.white24),
      minimumSize: const Size.fromHeight(44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
