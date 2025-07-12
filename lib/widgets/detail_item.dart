import 'package:flutter/material.dart';
import 'package:tasteturner/helper/utils.dart';

import '../constants.dart';

class DetailItem extends StatelessWidget {
  const DetailItem({
    super.key,
    required this.dataSrc,
    required this.onTap,
  });

  final Map<String, dynamic> dataSrc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double itemHeight = MediaQuery.of(context).size.height * 0.28;
    final double minHeight = 160;
    final double maxHeight = 260;
    final double usedHeight = itemHeight.clamp(minHeight, maxHeight);
    return SizedBox(
      height: usedHeight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: dataSrc['image'].startsWith('http')
                    ? buildOptimizedNetworkImage(
                        imageUrl: dataSrc['image'],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: BorderRadius.circular(20),
                      )
                    : Image.asset(
                        getAssetImageForItem(dataSrc['image']),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
              ),
            ),
          ),
          SizedBox(
            height: getPercentageHeight(1, context),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: getPercentageWidth(2, context)),
            child: Text(
              capitalizeFirstLetter(dataSrc['name']),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
