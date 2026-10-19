import 'package:flutter/material.dart';

class CategorySection extends StatefulWidget {
  final Function(String?)? onCategorySelected;

  const CategorySection({
    super.key,
    this.onCategorySelected,
  });

  @override
  State<CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<CategorySection> {
  int selectedIndex = -1;

  final categories = [
    Icons.house_outlined,
    Icons.apartment_outlined,
    Icons.landscape_outlined,
    Icons.business_outlined,
  ];

  final labels = ['House', 'Apartment', 'Land', 'Commercial'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(categories.length, (index) {
        final isSelected = selectedIndex == index;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 4,
              right: index == categories.length - 1 ? 0 : 4,
            ),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedIndex = isSelected ? -1 : index;
                });
                widget.onCategorySelected?.call(
                  isSelected ? null : labels[index].toLowerCase(),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isSelected ? null : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? null
                          : Border.all(color: Colors.grey.shade100, width: 1.5),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Icon(
                      categories[index],
                      size: 22,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 11,
                      color: isSelected
                          ? const Color(0xFF0F172A)
                          : Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
