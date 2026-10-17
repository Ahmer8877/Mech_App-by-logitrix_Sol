import 'package:flutter/material.dart';
import '../../widgets/app_text.dart';
import '../../cores/theme/app_theme.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/step_progress.dart';

class NewVehicleResult {
  final String make;
  final String plate;
  final String? year;
  const NewVehicleResult(this.make, this.plate, {this.year});
}

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _makeController = TextEditingController();
  final _plateController = TextEditingController();
  final _yearController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _makeController.dispose();
    _plateController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  void _submit() {
    final make = _makeController.text.trim();
    final plate = _plateController.text.trim();
    final year = _yearController.text.trim();

    if (make.isEmpty || plate.isEmpty || year.isEmpty) {
      setState(
        () => _error = 'Make & Model, License Plate and Year are required',
      );
      return;
    }

    final parsedYear = int.tryParse(year);
    if (parsedYear == null ||
        parsedYear < 1900 ||
        parsedYear > DateTime.now().year + 1) {
      setState(() => _error = 'Please enter a valid vehicle year');
      return;
    }

    setState(() => _error = null);
    Navigator.of(context).pop(NewVehicleResult(make, plate, year: year));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: const FlowAppBar(title: 'Add Vehicle'),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 36,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 100,
                          height: 70,
                          decoration: BoxDecoration(
                            color: c.surface2,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.directions_car_outlined,
                            size: 30,
                            color: c.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      AppText(
                        'MAKE & MODEL *',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: c.textMuted,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _makeController,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Suzuki Alto',
                        ),
                      ),
                      const SizedBox(height: 14),
                      AppText(
                        'LICENSE PLATE *',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: c.textMuted,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _plateController,
                        decoration: const InputDecoration(
                          hintText: 'e.g. LEZ 2022',
                        ),
                      ),
                      const SizedBox(height: 14),
                      AppText(
                        'YEAR *',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: c.textMuted,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _yearController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'e.g. 2022',
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        AppText(
                          _error!,
                          style: TextStyle(fontSize: 11.5, color: c.danger),
                        ),
                      ],
                      const Spacer(),
                      const SizedBox(height: 16),
                      AccentButton(label: 'Add Vehicle', onPressed: _submit),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
