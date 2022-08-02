import React from 'react';
import {
  ActivityIndicator,
  Text as DefaultText,
  TouchableOpacity as DefaultTouchableOpacity,
  TouchableOpacityProps,
} from 'react-native';
import styled from 'styled-components';

export type ButtonProps = TouchableOpacityProps & {
  isLoading?: boolean;
  title: string;
  textColor?: string;
  indicatorColor?: string;
};

export const Button = ({isLoading, textColor, title, disabled, indicatorColor, ...props}: ButtonProps) => (
  <TouchableOpacity {...props} disabled={disabled || isLoading}>
    {isLoading ? (
      <ActivityIndicator animating={isLoading} color={indicatorColor} />
    ) : (
      <Text style={{color: textColor}}>{title}</Text>
    )}
  </TouchableOpacity>
);

const TouchableOpacity = styled(DefaultTouchableOpacity)`
  opacity: ${({disabled}) => (disabled ? 0.7 : 1)};
`;

const Text = styled(DefaultText)`
  font-size: 18px;
`;
