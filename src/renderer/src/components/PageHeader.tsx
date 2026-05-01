import { Typography } from '@mui/material'

interface PageHeaderProps {
  title: string
}

export default function PageHeader({ title }: PageHeaderProps): React.JSX.Element {
  return (
    <Typography variant="h5" component="h1" sx={{ fontWeight: 600, mb: 2.5 }}>
      {title}
    </Typography>
  )
}
